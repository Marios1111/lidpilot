import Foundation
import Darwin

public struct DiagnosticEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let state: String
    public let message: String

    public init(id: UUID = UUID(), date: Date, state: String, message: String) {
        self.id = id
        self.date = date
        self.state = state
        self.message = message
    }
}

/// Small, local diagnostic storage with bounded age, count, content, and file size.
/// It never sends data anywhere and accepts an injected clock for deterministic tests.
public struct DiagnosticLog: Sendable {
    public static let maximumBytes = 5 * 1_024 * 1_024
    public static let retentionSeconds: TimeInterval = 7 * 86_400
    public static let maximumEntries = 2_000
    public static let maximumMessageCharacters = 400
    public static let maximumMessageUTF8Bytes = 512
    private static let maximumStateCharacters = 80
    private static let maximumStateUTF8Bytes = 256
    private static let maximumInputUTF8Bytes = 16 * 1_024
    private static let storageFailure = "Local diagnostics could not be saved."

    public private(set) var entries: [DiagnosticEntry] = []
    public private(set) var storageError: String?

    private let fileURL: URL?
    private let now: @Sendable () -> Date

    public init(fileURL: URL?, now: @escaping @Sendable () -> Date = { Date() }) {
        self.fileURL = fileURL
        self.now = now
        load()
    }

    public mutating func record(state: String, message: String, date: Date? = nil) {
        let current = now()
        let timestamp = date ?? current
        let entry = DiagnosticEntry(
            date: timestamp,
            state: Self.redact(state, limit: Self.maximumStateCharacters),
            message: Self.redact(message, limit: Self.maximumMessageCharacters)
        )
        entries.append(entry)
        entries = Self.pruned(entries, now: current)
        persist()
    }

    public mutating func clear() {
        entries.removeAll(keepingCapacity: false)
        persist()
    }

    /// Drops expired, future, invalid, and excess entries using the current clock.
    /// Existing entries have already been redacted when loaded or recorded, so
    /// refresh does not repeat the comparatively expensive sanitization pass.
    public mutating func refresh() {
        let pruned = Self.pruned(entries, now: now())
        guard pruned != entries else { return }
        entries = pruned
        persist()
    }

    private mutating func load() {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let size = (attributes[.size] as? NSNumber)?.int64Value,
               size > Int64(Self.maximumBytes) {
                try Self.write(Data("[]".utf8), to: fileURL)
                return
            }

            let data = try Data(contentsOf: fileURL)
            guard data.count <= Self.maximumBytes else {
                try Self.write(Data("[]".utf8), to: fileURL)
                return
            }

            let saved = try JSONDecoder().decode([DiagnosticEntry].self, from: data)
            let cleaned = Self.normalized(saved, now: now())
            entries = cleaned
            if cleaned != saved { persist() }
        } catch {
            entries.removeAll(keepingCapacity: false)
            do {
                try Self.write(Data("[]".utf8), to: fileURL)
            } catch {
                storageError = Self.storageFailure
            }
        }
    }

    private mutating func persist() {
        guard let fileURL else { return }
        do {
            var stored = entries
            var data = try JSONEncoder().encode(stored)
            while data.count > Self.maximumBytes, !stored.isEmpty {
                stored.removeFirst()
                data = try JSONEncoder().encode(stored)
            }
            entries = stored
            try Self.write(data, to: fileURL)
            storageError = nil
        } catch {
            storageError = Self.storageFailure
        }
    }

    private static func normalized(_ input: [DiagnosticEntry], now: Date) -> [DiagnosticEntry] {
        pruned(input, now: now).map {
            DiagnosticEntry(
                id: $0.id,
                date: $0.date,
                state: redact($0.state, limit: maximumStateCharacters),
                message: redact($0.message, limit: maximumMessageCharacters)
            )
        }
    }

    private static func pruned(_ input: [DiagnosticEntry], now: Date) -> [DiagnosticEntry] {
        let cutoff = now.addingTimeInterval(-retentionSeconds)
        let retained = input.filter { entry in
            guard entry.date.timeIntervalSinceReferenceDate.isFinite,
                  entry.date > cutoff, entry.date <= now else { return false }
            return true
        }
        return Array(retained.suffix(maximumEntries))
    }

    /// Removes common local paths, URLs, host/user labels, and workload-like
    /// values before the bounded message is retained.
    internal static func redact(_ value: String, limit: Int) -> String {
        var result = boundedUTF8Prefix(value, maximumBytes: maximumInputUTF8Bytes)
        result = result.replacingOccurrences(
            of: #"(?i)\b(?:https?|file)://[^\s,;]+"#,
            with: "[url]",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?i)(?:~|/(?:Users|private|var|Library|System|Applications|tmp|Volumes)/)[^\s,;\"']+"#,
            with: "[path]",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?i)\b(?:host(?:name)?|user(?:name)?|machine|connection|endpoint|payload|prompt|transcript|workload|command)\s*[:=]\s*[^\s,;]+"#,
            with: "[redacted]",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?i)\b[A-Za-z0-9][A-Za-z0-9._-]*\.local\b"#,
            with: "[host]",
            options: .regularExpression
        )
        result = String(result.prefix(limit))
        let outputBytes = limit <= maximumStateCharacters ? maximumStateUTF8Bytes : maximumMessageUTF8Bytes
        return boundedUTF8Prefix(result, maximumBytes: outputBytes)
    }

    private static func boundedUTF8Prefix(_ value: String, maximumBytes: Int) -> String {
        guard maximumBytes > 0 else { return "" }
        let bytes = value.utf8
        guard var end = bytes.index(bytes.startIndex, offsetBy: maximumBytes, limitedBy: bytes.endIndex) else {
            return value
        }
        while end > bytes.startIndex {
            if let bounded = String(bytes: bytes[..<end], encoding: .utf8) {
                return bounded
            }
            end = bytes.index(before: end)
        }
        return ""
    }

    private static func write(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let temporary = directory.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw RuntimeFailure.unavailable("diagnostic temporary file open failed") }
        defer {
            close(descriptor)
            try? FileManager.default.removeItem(at: temporary)
        }

        try data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            var written = 0
            while written < bytes.count {
                let count = Darwin.write(descriptor, baseAddress.advanced(by: written), bytes.count - written)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw RuntimeFailure.unavailable("diagnostic file write failed") }
                written += count
            }
        }
        guard fsync(descriptor) == 0 else { throw RuntimeFailure.unavailable("diagnostic file sync failed") }
        guard rename(temporary.path, url.path) == 0 else {
            throw RuntimeFailure.unavailable("diagnostic file replacement failed")
        }
    }
}
