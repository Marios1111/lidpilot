import Foundation
import Darwin
import Testing
@testable import LidPilotRuntime

struct PMSetDriverTests {
    @Test func publicDriverIsReadOnlyWithoutTrustedFence() {
        let driver = PMSetDriver()
        #expect(throws: (any Error).self) { try driver.setDisabled(true) }
        #expect(throws: (any Error).self) {
            try driver.withMutationFence { try driver.setDisabled(true) }
        }
    }

    @Test func commandFenceCreatesAndValidatesPrivateLockFile() throws {
        let folder = try TestFenceDirectory()
        defer { folder.remove() }

        let fence = try CommandFence(directoryDescriptor: folder.descriptor, owner: geteuid())
        let lockDescriptor = folder.commandDescriptor()
        defer { close(lockDescriptor) }
        var info = stat()
        #expect(fstat(lockDescriptor, &info) == 0)
        #expect(info.st_mode & S_IFMT == S_IFREG)
        #expect(info.st_mode & 0o777 == 0o600)
        #expect(info.st_nlink == 1)
        withExtendedLifetime(fence) {}
    }

    @Test func commandFenceRejectsSymlinkAndLoosePermissions() throws {
        let symlinkFolder = try TestFenceDirectory(createLock: false)
        defer { symlinkFolder.remove() }
        let target = symlinkFolder.url.appendingPathComponent("target")
        try Data("unrelated".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(
            at: symlinkFolder.url.appendingPathComponent("command.lock"),
            withDestinationURL: target
        )
        #expect(throws: (any Error).self) {
            try CommandFence(directoryDescriptor: symlinkFolder.descriptor, owner: geteuid())
        }

        let looseFolder = try TestFenceDirectory(createLock: false)
        defer { looseFolder.remove() }
        let lock = looseFolder.url.appendingPathComponent("command.lock")
        _ = FileManager.default.createFile(atPath: lock.path, contents: Data(), attributes: nil)
        chmod(lock.path, 0o644)
        #expect(throws: (any Error).self) {
            try CommandFence(directoryDescriptor: looseFolder.descriptor, owner: geteuid())
        }
    }

    @Test func runnerBoundsExecutionAndReapsTimedOutChild() throws {
        let runner = POSIXCommandRunner(executable: "/bin/sleep", timeout: 0.05)
        do {
            _ = try runner.run(arguments: ["1"], inheritedFence: nil)
            Issue.record("sleep unexpectedly completed")
        } catch let error as POSIXCommandError {
            #expect(error == .timedOut(childReaped: true))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func runnerDrainsButBoundsOutput() throws {
        let runner = POSIXCommandRunner(executable: "/usr/bin/printf", timeout: 1)
        let payload = String(repeating: "x", count: 20_000)
        do {
            _ = try runner.run(arguments: [payload], inheritedFence: nil)
            Issue.record("oversized output unexpectedly succeeded")
        } catch let error as POSIXCommandError {
            #expect(error == .outputTooLarge)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func inheritedFenceStaysBusyAfterParentDescriptorCloses() throws {
        let folder = try TestFenceDirectory()
        defer { folder.remove() }
        let fence = try CommandFence(directoryDescriptor: folder.descriptor, owner: geteuid())
        let runner = POSIXCommandRunner(executable: "/bin/sleep", timeout: 1)
        let child: RunningPOSIXCommand = try fence.withExclusive {
            guard let descriptor = fence.descriptorForCurrentBody() else {
                throw RuntimeFailure.unavailable("test fence was not active")
            }
            let child = try runner.spawn(arguments: ["0.25"], inheritedFence: descriptor)
            close(child.outputDescriptor)
            fence.retainForInheritedChild()
            return child
        }

        do {
            try fence.withExclusive(timeout: 0.05) {}
            Issue.record("the inherited child did not retain the command fence")
        } catch let error as RuntimeFailure {
            #expect(error == .unavailable("Timed out waiting for the command fence."))
        } catch {
            Issue.record("unexpected error while the inherited child holds the fence: \(error)")
        }
        let competing = try CommandFence(directoryDescriptor: folder.descriptor, owner: geteuid())
        do {
            try competing.withExclusive(timeout: 0.05) {}
            Issue.record("a competing fence acquired the lock while the child was running")
        } catch let error as RuntimeFailure {
            #expect(error == .unavailable("Timed out waiting for the command fence."))
        } catch {
            Issue.record("unexpected error from a competing fence: \(error)")
        }

        var status: Int32 = 0
        #expect(waitpid(child.pid, &status, 0) == child.pid)
        try competing.withExclusive(timeout: 0.5) {}
        // The running helper must also recover through the same fence object.
        try fence.withExclusive(timeout: 0.5) {
            #expect(fence.descriptorForCurrentBody() != nil)
        }
    }
}

@Suite(.serialized)
struct POSIXCommandRunnerRegressionTests {
    @Test func runnerDoesNotBusyLoopWhenChildClosesOutputBeforeExit() throws {
        let runner = POSIXCommandRunner(executable: "/bin/sh", timeout: 1)
        let before = try currentThreadCPUSeconds()
        let start = DispatchTime.now().uptimeNanoseconds
        let output = try runner.run(
            arguments: ["-c", "exec 1>&- 2>&-; /bin/sleep 0.3"],
            inheritedFence: nil
        )
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
        let cpuUsed = try currentThreadCPUSeconds() - before

        #expect(output.isEmpty)
        #expect(elapsed >= 0.25)
        #expect(cpuUsed < elapsed * 0.05)
    }
}

private func currentThreadCPUSeconds() throws -> Double {
    let thread = mach_thread_self()
    defer { mach_port_deallocate(mach_task_self_, thread) }

    var info = thread_basic_info_data_t()
    var count = mach_msg_type_number_t(
        MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<natural_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            thread_info(thread, thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else {
        throw RuntimeFailure.unavailable("could not read current-thread CPU time (\(result))")
    }

    let user = Double(info.user_time.seconds) + Double(info.user_time.microseconds) / 1_000_000
    let system = Double(info.system_time.seconds) + Double(info.system_time.microseconds) / 1_000_000
    return user + system
}

private final class TestFenceDirectory {
    let url: URL
    let descriptor: Int32

    init(createLock: Bool = true) throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lidpilot-command-fence-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        chmod(url.path, 0o700)
        descriptor = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw RuntimeFailure.unavailable("test directory open failed") }
        if !createLock { return }
    }

    func commandDescriptor() -> Int32 {
        openat(descriptor, "command.lock", O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
    }

    func remove() {
        close(descriptor)
        try? FileManager.default.removeItem(at: url)
    }
}
