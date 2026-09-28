import Foundation
import Darwin
import LidPilotCore

public enum CLIFileOperations {
    public static func hookInstallation(at url: URL, source: WorkloadSource, executable: URL) throws -> HookConfiguration.Installation {
        var info = stat()
        guard lstat(url.path, &info) == 0 else {
            if errno == ENOENT { return .missing }
            throw ControlError.unsafePath
        }
        return try HookConfiguration.installation(readHooks(at: url, expected: info), source: source,
            executable: executable.resolvingSymlinksInPath().path)
    }

    private static func readHooks(at url: URL, expected: stat) throws -> Data {
        guard expected.st_mode & S_IFMT == S_IFREG, expected.st_uid == getuid(), expected.st_nlink == 1,
              expected.st_mode & 0o022 == 0, expected.st_size <= 1_048_576 else { throw ControlError.unsafePath }
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw ControlError.unsafePath }
        defer { close(fd) }
        var opened = stat()
        guard fstat(fd, &opened) == 0, opened.st_ino == expected.st_ino, opened.st_dev == expected.st_dev else { throw ControlError.busy }
        let data = try FileHandle(fileDescriptor: fd, closeOnDealloc: false).read(upToCount: 1_048_577) ?? Data()
        guard data.count <= 1_048_576 else { throw ControlError.oversized }
        return data
    }

    public static func export(_ data: Data, to url: URL) throws {
        let fd = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw ControlError.conflictError }
        defer { close(fd) }
        try write(data, fd: fd)
    }

    public static func install(executable: URL, directory: URL, remove: Bool = false) throws {
        var info = stat()
        guard lstat(directory.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == getuid(), info.st_mode & 0o022 == 0 else { throw ControlError.unsafePath }
        let link = directory.appendingPathComponent("lidpilot").path
        let target = executable.resolvingSymlinksInPath().path
        if remove {
            guard lstat(link, &info) == 0, info.st_mode & S_IFMT == S_IFLNK,
                  try FileManager.default.destinationOfSymbolicLink(atPath: link) == target else { throw ControlError.unsafePath }
            guard unlink(link) == 0 else { throw ControlError.unsafePath }
        } else {
            guard FileManager.default.isExecutableFile(atPath: target) else { throw ControlError.unavailable }
            guard symlink(target, link) == 0 else { throw ControlError.conflictError }
        }
    }

    public static func configureHooks(at url: URL, source: WorkloadSource, version: String, executable: URL, install: Bool) throws {
        let parent = url.deletingLastPathComponent()
        var directory = stat()
        guard lstat(parent.path, &directory) == 0, directory.st_mode & S_IFMT == S_IFDIR,
              directory.st_uid == getuid(), directory.st_mode & 0o022 == 0 else { throw ControlError.unsafePath }
        var original = stat()
        let exists = lstat(url.path, &original) == 0
        var prior: Data?
        if exists {
            prior = try readHooks(at: url, expected: original)
        }
        let replacement = try HookConfiguration.updated(prior, source: source, version: version,
            executable: executable.resolvingSymlinksInPath().path, install: install)
        let temporary = parent.appendingPathComponent(".lidpilot-hooks-\(UUID().uuidString)")
        try export(replacement, to: temporary)
        defer { unlink(temporary.path) }
        var current = stat()
        if exists {
            guard lstat(url.path, &current) == 0, current.st_ino == original.st_ino, current.st_dev == original.st_dev,
                  try Data(contentsOf: url) == prior else { throw ControlError.busy }
            guard rename(temporary.path, url.path) == 0 else { throw ControlError.unsafePath }
        } else {
            // An exclusive hard link publishes without overwriting a config
            // created concurrently by the agent or another installation.
            guard link(temporary.path, url.path) == 0 else { throw ControlError.busy }
        }
    }

    private static func write(_ data: Data, fd: Int32) throws {
        try data.withUnsafeBytes { bytes in
            var written = 0
            while written < bytes.count {
                let n = Darwin.write(fd, bytes.baseAddress!.advanced(by: written), bytes.count - written)
                if n < 0, errno == EINTR { continue }
                guard n > 0 else { throw ControlError.unsafePath }
                written += n
            }
        }
        guard fsync(fd) == 0 else { throw ControlError.unsafePath }
    }
}

private extension ControlError {
    static var conflictError: NSError { NSError(domain: "com.lidpilot.cli", code: 73, userInfo: [NSLocalizedDescriptionKey: "The destination already exists or cannot be written. Nothing was overwritten."]) }
}
