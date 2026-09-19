import Foundation
import Darwin

/// The child inherits the locked open-file description on stdin. Never explicitly
/// unlock that description while a child might still be alive.
internal final class CommandFence: @unchecked Sendable {
    private let stateLock = NSLock()
    private let directory: Int32
    private let owner: uid_t
    private let device: dev_t
    private let inode: ino_t
    private var descriptor: Int32
    private var activeThread: UInt64?
    private var holding = false
    private var childMayLive = false

    internal init(directoryDescriptor: Int32, owner: uid_t) throws {
        var directoryInfo = stat()
        guard fstat(directoryDescriptor, &directoryInfo) == 0,
              directoryInfo.st_mode & S_IFMT == S_IFDIR,
              directoryInfo.st_uid == owner, directoryInfo.st_mode & 0o077 == 0 else {
            throw RuntimeFailure.unavailable("The command-fence directory is not trusted.")
        }
        directory = fcntl(directoryDescriptor, F_DUPFD_CLOEXEC, 3)
        guard directory >= 0 else { throw Self.failure("retain command-fence directory") }
        self.owner = owner
        do {
            let (fd, info) = try Self.openValidated(directory: directory, owner: owner)
            descriptor = fd
            device = info.st_dev
            inode = info.st_ino
        } catch { close(directory); throw error }
    }

    deinit {
        // Closing our copy preserves any inherited child's lock.
        if descriptor >= 0 { close(descriptor) }
        close(directory)
    }

    internal func withExclusive<T>(timeout: TimeInterval = 5, _ body: () throws -> T) throws -> T {
        let thread = UInt64(pthread_mach_thread_np(pthread_self()))
        stateLock.lock()
        guard activeThread == nil else {
            stateLock.unlock()
            throw RuntimeFailure.unavailable("A command-fence transaction is already in progress.")
        }
        activeThread = thread
        stateLock.unlock()
        defer {
            stateLock.lock(); activeThread = nil; stateLock.unlock()
        }

        if descriptor < 0 {
            let (fd, info) = try Self.openValidated(directory: directory, owner: owner)
            guard info.st_dev == device, info.st_ino == inode else {
                close(fd)
                throw RuntimeFailure.unavailable("The command-fence identity changed; recovery requires attention.")
            }
            descriptor = fd
        }
        let fd = descriptor
        try acquire(fd, timeout: timeout)
        stateLock.lock(); holding = true; childMayLive = false; stateLock.unlock()
        var bodyError: (any Error)?
        var result: T?
        do { result = try body() } catch { bodyError = error }

        stateLock.lock()
        let preserveChild = childMayLive
        holding = false
        stateLock.unlock()
        if preserveChild {
            // The next transaction reopens the same inode and must win a fresh
            // flock before any read/recovery. This remains recoverable in-process.
            close(fd)
            descriptor = -1
        } else if flock(fd, LOCK_UN) != 0 {
            let error = Self.failure("release command fence")
            close(fd)
            descriptor = -1
            if bodyError == nil { bodyError = error }
        }
        if let bodyError { throw bodyError }
        return result!
    }

    internal func descriptorForCurrentBody() -> Int32? {
        stateLock.lock(); defer { stateLock.unlock() }
        guard holding, !childMayLive,
              activeThread == UInt64(pthread_mach_thread_np(pthread_self())) else { return nil }
        return descriptor
    }

    internal func retainForInheritedChild() {
        stateLock.lock(); defer { stateLock.unlock() }
        if activeThread == UInt64(pthread_mach_thread_np(pthread_self())) { childMayLive = true }
    }

    private func acquire(_ fd: Int32, timeout: TimeInterval) throws {
        guard timeout.isFinite else { throw Self.failure("validate fence timeout") }
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(min(max(timeout, 0), 5) * 1_000_000_000)
        while true {
            if flock(fd, LOCK_EX | LOCK_NB) == 0 { return }
            guard errno == EWOULDBLOCK || errno == EAGAIN || errno == EINTR else {
                throw Self.failure("acquire command fence")
            }
            guard DispatchTime.now().uptimeNanoseconds < deadline else {
                throw RuntimeFailure.unavailable("Timed out waiting for the command fence.")
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    private static func openValidated(directory: Int32, owner: uid_t) throws -> (Int32, stat) {
        let opened = openat(directory, "command.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
        guard opened >= 0 else { throw failure("open command fence") }
        var info = stat()
        guard fstat(opened, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_uid == owner, info.st_nlink == 1, info.st_mode & 0o777 == 0o600 else {
            close(opened)
            throw RuntimeFailure.unavailable("The command-fence file has unsafe ownership or permissions.")
        }
        // Ensure dup2 to stdin always clears close-on-exec on the child's copy.
        if opened < 3 {
            let duplicate = fcntl(opened, F_DUPFD_CLOEXEC, 3)
            close(opened)
            guard duplicate >= 0 else { throw failure("duplicate command fence") }
            return (duplicate, info)
        }
        return (opened, info)
    }

    private static func failure(_ operation: String) -> RuntimeFailure {
        .unavailable("Cannot \(operation) (errno \(errno)).")
    }
}
