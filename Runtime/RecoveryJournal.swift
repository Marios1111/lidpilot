import Foundation
import Darwin

public enum RecoveryPhase: String, Codable, Sendable {
    case prepared
    case enableInFlight
    case enabledVerified
    case restoreAuthorized
}

public struct RecoveryRecord: Codable, Equatable, Sendable {
    public let version: Int
    public let sessionID: UUID
    public let generation: UInt64
    public let bootID: String
    public let phase: RecoveryPhase
    public init(sessionID: UUID, generation: UInt64, bootID: String, phase: RecoveryPhase = .enabledVerified) {
        version = 2
        self.sessionID = sessionID
        self.generation = generation
        self.bootID = bootID
        self.phase = phase
    }
}

public protocol RecoveryStoring: Sendable {
    func load() throws -> RecoveryRecord?
    func save(_ record: RecoveryRecord) throws
    func clear() throws
}

/// The helper supplies the fixed production location. The XPC protocol accepts no paths.
public final class RecoveryJournal: RecoveryStoring, @unchecked Sendable {
    private let directory: Int32
    private let owner: uid_t
    private let filename = "recovery.json"

    public static func privileged() throws -> RecoveryJournal {
        for path in ["/Library", "/Library/Application Support"] {
            var info = stat()
            guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
                  info.st_uid == 0, info.st_mode & 0o022 == 0 else {
                throw RuntimeFailure.unavailable("Recovery directory ancestry is not trusted.")
            }
        }
        return try RecoveryJournal(directory: "/Library/Application Support/LidPilot", owner: 0)
    }

    // Internal initializer is also used by tests with a disposable directory and current uid.
    init(directory path: String, owner: uid_t) throws {
        self.owner = owner
        if mkdir(path, 0o700) != 0, errno != EEXIST { throw Self.failure("create directory") }
        let openedDirectory = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard openedDirectory >= 0 else { throw Self.failure("open directory") }
        var info = stat()
        guard fstat(openedDirectory, &info) == 0, info.st_uid == owner,
              info.st_mode & S_IFMT == S_IFDIR, info.st_mode & 0o077 == 0 else {
            close(openedDirectory)
            throw RuntimeFailure.unavailable("Recovery directory ownership or permissions are unsafe.")
        }
        // Transfer FD ownership only after validation; throwing after assigning it
        // would run deinit and close the same descriptor again during unwinding.
        directory = openedDirectory
    }

    deinit { close(directory) }

    public func makePowerDriver() throws -> PMSetDriver {
        try PMSetDriver(fence: CommandFence(directoryDescriptor: directory, owner: owner))
    }

    public func load() throws -> RecoveryRecord? {
        let file = openat(directory, filename, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        if file < 0, errno == ENOENT { return nil }
        guard file >= 0 else { throw Self.failure("open record") }
        defer { close(file) }
        var info = stat()
        guard fstat(file, &info) == 0, info.st_uid == owner,
              info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o077 == 0,
              info.st_nlink == 1, info.st_size > 0, info.st_size <= 4_096 else {
            throw RuntimeFailure.unavailable("Recovery record is damaged or has unsafe permissions.")
        }
        var bytes = [UInt8](repeating: 0, count: Int(info.st_size))
        let count = bytes.withUnsafeMutableBytes { Darwin.read(file, $0.baseAddress, $0.count) }
        guard count == bytes.count else { throw Self.failure("read record") }
        let record = try JSONDecoder().decode(RecoveryRecord.self, from: Data(bytes))
        guard record.version == 2, record.generation > 0, !record.bootID.isEmpty else {
            throw RuntimeFailure.unavailable("Recovery record version or identity is invalid.")
        }
        return record
    }

    public func save(_ record: RecoveryRecord) throws {
        let bytes = try JSONEncoder().encode(record)
        let temporary = ".recovery-\(UUID().uuidString)"
        let file = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard file >= 0 else { throw Self.failure("create record") }
        defer { close(file); unlinkat(directory, temporary, 0) }
        try bytes.withUnsafeBytes { buffer in
            var written = 0
            while written < buffer.count {
                let count = Darwin.write(file, buffer.baseAddress!.advanced(by: written), buffer.count - written)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw Self.failure("write record") }
                written += count
            }
        }
        guard fsync(file) == 0, renameat(directory, temporary, directory, filename) == 0,
              fsync(directory) == 0 else { throw Self.failure("persist record") }
    }

    public func clear() throws {
        if unlinkat(directory, filename, 0) != 0, errno != ENOENT { throw Self.failure("remove record") }
        guard fsync(directory) == 0 else { throw Self.failure("persist removal") }
    }

    private static func failure(_ operation: String) -> RuntimeFailure {
        .unavailable("Cannot \(operation) in the recovery journal (errno \(errno)).")
    }
}
