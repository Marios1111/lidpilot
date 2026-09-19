import Foundation
import Darwin
import Testing
@testable import LidPilotRuntime

struct DiagnosticLogTests {
    @Test func recordsRedactedAndBoundedMessages() {
        let now = Date(timeIntervalSince1970: 100)
        var log = DiagnosticLog(fileURL: nil, now: { now })
        let message = "host=marios-MacBook.local user=marios at /Users/marios/Secrets/result.txt " +
            "url=https://example.com/private connection=private payload=workload-123 " + String(repeating: "x", count: 1_000)
        log.record(state: String(repeating: "state", count: 40), message: message, date: now)

        #expect(log.entries.count == 1)
        let entry = log.entries[0]
        #expect(entry.message.count <= DiagnosticLog.maximumMessageCharacters)
        #expect(entry.state.count <= 80)
        #expect(!entry.message.contains("/Users"))
        #expect(!entry.message.contains("marios"))
        #expect(!entry.message.contains("result.txt"))
        #expect(!entry.message.contains("https://"))
        #expect(entry.message.contains("[path]"))
        #expect(entry.message.contains("[url]"))
        #expect(entry.message.contains("[redacted]"))
    }

    @Test func refreshPrunesAfterInjectedClockAdvancesAndPersists() throws {
        let folder = try TestFolder()
        defer { folder.remove() }
        let clock = TestClock(Date(timeIntervalSince1970: 1_000_000))
        var log = DiagnosticLog(fileURL: folder.file, now: { clock.date })
        log.record(state: "active", message: "still useful", date: clock.date)
        let before = try Data(contentsOf: folder.file)

        clock.date = clock.date.addingTimeInterval(DiagnosticLog.retentionSeconds + 1)
        log.refresh()

        #expect(log.entries.isEmpty)
        let after = try Data(contentsOf: folder.file)
        #expect(after != before)
        #expect(try JSONDecoder().decode([DiagnosticEntry].self, from: after).isEmpty)
    }

    @Test func pathologicalGraphemeIsUTF8BoundedBeforePersistence() throws {
        let folder = try TestFolder()
        defer { folder.remove() }
        let now = Date(timeIntervalSince1970: 1_000_000)
        var log = DiagnosticLog(fileURL: folder.file, now: { now })
        let pathological = "e" + String(repeating: "\u{0301}", count: DiagnosticLog.maximumBytes + 1_024)

        log.record(state: "active", message: pathological, date: now)

        #expect(log.entries.count == 1)
        #expect(log.entries[0].message.utf8.count <= DiagnosticLog.maximumMessageUTF8Bytes)
        #expect(try Data(contentsOf: folder.file).count <= DiagnosticLog.maximumBytes)
    }

    @Test func loadDropsExpiredFutureAndExcessEntries() throws {
        let folder = try TestFolder()
        defer { folder.remove() }
        let now = Date(timeIntervalSince1970: 1_000_000)
        var saved = [DiagnosticEntry](repeating: DiagnosticEntry(date: now, state: "old", message: "old"), count: 5)
        saved += (0..<2_005).map {
            DiagnosticEntry(date: now.addingTimeInterval(-TimeInterval(2_005 - $0)), state: "active", message: "event-\($0)")
        }
        saved.append(DiagnosticEntry(date: now.addingTimeInterval(-8 * 86_400), state: "expired", message: "expired"))
        saved.append(DiagnosticEntry(date: now.addingTimeInterval(60), state: "future", message: "future"))
        try JSONEncoder().encode(saved).write(to: folder.file)

        let log = DiagnosticLog(fileURL: folder.file, now: { now })
        #expect(log.entries.count == DiagnosticLog.maximumEntries)
        #expect(log.entries.first?.message == "event-5")
        #expect(log.entries.last?.message == "event-2004")
        #expect(log.entries.allSatisfy { $0.date <= now && $0.date > now.addingTimeInterval(-DiagnosticLog.retentionSeconds) })
    }

    @Test func malformedAndOversizedFilesRotateToEmptyBoundedStorage() throws {
        let malformedFolder = try TestFolder()
        defer { malformedFolder.remove() }
        try Data("not-json".utf8).write(to: malformedFolder.file)
        _ = DiagnosticLog(fileURL: malformedFolder.file)
        let malformedData = try Data(contentsOf: malformedFolder.file)
        #expect(try JSONDecoder().decode([DiagnosticEntry].self, from: malformedData).isEmpty)
        #expect(malformedData.count <= DiagnosticLog.maximumBytes)

        let oversizedFolder = try TestFolder()
        defer { oversizedFolder.remove() }
        try Data(repeating: 0x78, count: DiagnosticLog.maximumBytes + 1).write(to: oversizedFolder.file)
        _ = DiagnosticLog(fileURL: oversizedFolder.file)
        let oversizedData = try Data(contentsOf: oversizedFolder.file)
        #expect(try JSONDecoder().decode([DiagnosticEntry].self, from: oversizedData).isEmpty)
        #expect(oversizedData.count <= DiagnosticLog.maximumBytes)
    }

    @Test func persistedDataStaysWithinSizeAndPermissionBounds() throws {
        let folder = try TestFolder()
        defer { folder.remove() }
        let now = Date(timeIntervalSince1970: 1_000_000)
        let seed = (0..<DiagnosticLog.maximumEntries).map { index in
            DiagnosticEntry(
                date: now.addingTimeInterval(-TimeInterval(DiagnosticLog.maximumEntries - index)),
                state: "active",
                message: String(repeating: "event-\(index)-", count: 40)
            )
        }
        try JSONEncoder().encode(seed).write(to: folder.file)

        var log = DiagnosticLog(fileURL: folder.file, now: { now })
        log.record(state: "active", message: "final", date: now)

        let data = try Data(contentsOf: folder.file)
        #expect(data.count <= DiagnosticLog.maximumBytes)
        var info = stat()
        #expect(stat(folder.file.path, &info) == 0)
        #expect(info.st_mode & 0o777 == 0o600)
    }

    @Test func nilFileURLKeepsPreviewDiagnosticsInMemoryOnly() {
        let now = Date(timeIntervalSince1970: 100)
        var log = DiagnosticLog(fileURL: nil, now: { now })
        log.record(state: "active", message: "preview", date: now)
        #expect(log.entries.count == 1)
        #expect(log.storageError == nil)
    }
}

private final class TestFolder {
    let url: URL
    let file: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lidpilot-diagnostic-log-\(UUID())")
        file = url.appendingPathComponent("diagnostics.json")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
    }

    func remove() { try? FileManager.default.removeItem(at: url) }
}

private final class TestClock: @unchecked Sendable {
    var date: Date

    init(_ date: Date) { self.date = date }
}
