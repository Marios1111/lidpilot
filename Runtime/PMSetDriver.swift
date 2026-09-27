import Foundation
import Darwin
import LidPilotCore

public enum RuntimeFailure: Error, LocalizedError, Equatable {
    case unavailable(String)
    public var errorDescription: String? {
        switch self { case .unavailable(let message): return message }
    }
}

public protocol SleepFlagControlling: Sendable {
    func read() throws -> FlagState
    func setDisabled(_ disabled: Bool) throws
    func withMutationFence<T>(_ operation: () throws -> T) throws -> T
}

public extension SleepFlagControlling {
    func withMutationFence<T>(_ operation: () throws -> T) throws -> T {
        try operation()
    }
}

/// There is deliberately no executable, argument, environment, or path parameter in this API.
public struct PMSetDriver: SleepFlagControlling, Sendable {
    private let fence: CommandFence?
    private let runner: POSIXCommandRunner

    /// The public driver is read-only. The helper obtains a fenced driver from
    /// the trusted recovery directory through the internal initializer.
    public init() {
        fence = nil
        runner = POSIXCommandRunner(executable: "/usr/bin/pmset")
    }

    internal init(fence: CommandFence) {
        self.fence = fence
        runner = POSIXCommandRunner(executable: "/usr/bin/pmset")
    }

    // Internal-only seam for bounded tests. Production construction keeps the
    // executable and arguments fixed to pmset below.
    internal init(fence: CommandFence, runner: POSIXCommandRunner) {
        self.fence = fence
        self.runner = runner
    }

    public func read() throws -> FlagState {
        Self.parse(try run(arguments: ["-g"]))
    }

    public func setDisabled(_ disabled: Bool) throws {
        guard geteuid() == 0 else { throw RuntimeFailure.unavailable("The approved helper is required.") }
        guard fence?.descriptorForCurrentBody() != nil else {
            throw RuntimeFailure.unavailable("A trusted command fence is required.")
        }
        _ = try run(arguments: ["-a", "disablesleep", disabled ? "1" : "0"])
    }

    public func withMutationFence<T>(_ operation: () throws -> T) throws -> T {
        guard let fence else {
            throw RuntimeFailure.unavailable("The approved helper is required for mutations.")
        }
        return try fence.withExclusive { try operation() }
    }

    public static func parse(_ output: String) -> FlagState {
        let values = output.split(separator: "\n").compactMap { line -> String? in
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.first == "SleepDisabled", fields.count == 2 else { return nil }
            return String(fields[1])
        }
        guard values.count == 1 else { return .unknown }
        switch values[0] { case "0": return .off; case "1": return .on; default: return .unknown }
    }

    private func run(arguments: [String]) throws -> String {
        #if LIDPILOT_PROFILE
        return try PerformanceTrace.span(operation: arguments == ["-g"] ? "read" : (arguments.last == "1" ? "enable" : "restore")) {
            try runUnprofiled(arguments: arguments)
        }
        #else
        return try runUnprofiled(arguments: arguments)
        #endif
    }

    private func runUnprofiled(arguments: [String]) throws -> String {
        let inheritedFence = fence?.descriptorForCurrentBody()
        do {
            return try runner.run(arguments: arguments, inheritedFence: inheritedFence)
        } catch let error as POSIXCommandError {
            if case .timedOut(childReaped: false) = error {
                fence?.retainForInheritedChild()
            } else if case .childNotReaped = error {
                fence?.retainForInheritedChild()
            }
            throw RuntimeFailure.unavailable(error.message)
        }
    }
}

internal enum POSIXCommandError: Error, Equatable {
    case spawn(String)
    case io(String)
    case timedOut(childReaped: Bool)
    case childNotReaped(String)
    case failed(Int32)
    case outputTooLarge

    var message: String {
        switch self {
        case .spawn(let message): return "Could not start power command: \(message)."
        case .io(let message): return "Power command I/O failed: \(message)."
        case .timedOut(let childReaped):
            return childReaped
                ? "Power command timed out; recovery is required."
                : "Power command timed out and could not be reaped; recovery is required."
        case .childNotReaped(let message):
            return "Power command child could not be reaped: \(message)."
        case .failed(let status): return "Power command failed (status \(status))."
        case .outputTooLarge: return "Power command output exceeded the safety limit."
        }
    }
}

internal struct RunningPOSIXCommand: Sendable {
    let pid: pid_t
    let outputDescriptor: Int32
}

/// The runner defaults to the real Darwin calls. Internal injection keeps the
/// failed-reap path deterministic in tests without changing production behavior.
internal struct POSIXCommandSyscalls: Sendable {
    let waitForProcess: @Sendable (pid_t, UnsafeMutablePointer<Int32>, Int32) -> pid_t
    let sendSignal: @Sendable (pid_t, Int32) -> Int32

    internal static let darwin = POSIXCommandSyscalls(
        waitForProcess: { Darwin.waitpid($0, $1, $2) },
        sendSignal: { Darwin.kill($0, $1) }
    )
}

/// Fixed-environment POSIX execution with a bounded wait and bounded drain.
/// This type is internal so tests can exercise `/bin/sleep` or `/usr/bin/printf`
/// without expanding PMSetDriver's public command surface.
internal struct POSIXCommandRunner: Sendable {
    private static let maxOutputBytes = 16_384
    private static let maxExecutionSeconds: TimeInterval = 5
    private static let finalDrainSeconds: TimeInterval = 0.25
    private static let environment = [
        "PATH=/usr/bin:/bin",
        "LANG=C",
        "LC_ALL=C",
        "HOME=/var/empty"
    ]

    private let executable: String
    private let timeout: TimeInterval
    private let syscalls: POSIXCommandSyscalls

    internal init(executable: String,
                  timeout: TimeInterval = POSIXCommandRunner.maxExecutionSeconds,
                  syscalls: POSIXCommandSyscalls = .darwin) {
        self.executable = executable
        self.timeout = min(max(timeout, 0), Self.maxExecutionSeconds)
        self.syscalls = syscalls
    }

    internal func run(arguments: [String], inheritedFence: Int32?) throws -> String {
        let child = try spawn(arguments: arguments, inheritedFence: inheritedFence)
        #if LIDPILOT_PROFILE
        PerformanceTrace.event("spawn", fields: ["child_pid": String(child.pid), "callsite": PerformanceTrace.currentCallsite, "span_id": PerformanceTrace.currentSpanID ?? "none"])
        #endif
        defer { close(child.outputDescriptor) }

        var output = Data()
        var outputTooLarge = false
        var status: Int32 = 0
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(timeout * 1_000_000_000)
        var childReaped = false

        do {
            while true {
                let waited = syscalls.waitForProcess(child.pid, &status, WNOHANG)
                if waited == child.pid {
                    childReaped = true
                    if try drain(child.outputDescriptor, into: &output, tooLarge: &outputTooLarge) {
                        break
                    }
                    try finishDrain(child.outputDescriptor, into: &output, tooLarge: &outputTooLarge)
                    break
                }
                if waited < 0 {
                    if errno == EINTR { continue }
                    if errno == ECHILD {
                        childReaped = true // It is no longer ours; never signal a possibly reused PID.
                        throw POSIXCommandError.io("waitpid lost child")
                    }
                    throw POSIXCommandError.io("waitpid errno \(errno)")
                }

                let outputClosed = try drain(child.outputDescriptor, into: &output, tooLarge: &outputTooLarge)
                if DispatchTime.now().uptimeNanoseconds >= deadline {
                    throw POSIXCommandError.timedOut(childReaped: false)
                }
                let waitMilliseconds = millisecondsUntil(deadline: deadline, maximum: 20)
                guard waitMilliseconds > 0 else {
                    throw POSIXCommandError.timedOut(childReaped: false)
                }
                if outputClosed {
                    // EOF makes poll report HUP immediately even when the child
                    // is still running. Keep checking waitpid without spinning.
                    Thread.sleep(forTimeInterval: Double(waitMilliseconds) / 1_000)
                } else {
                    _ = try waitForOutput(child.outputDescriptor, milliseconds: waitMilliseconds)
                }
            }

            if outputTooLarge { throw POSIXCommandError.outputTooLarge }
            guard status == 0 else { throw POSIXCommandError.failed(status) }
            return String(decoding: output, as: UTF8.self)
        } catch let error as POSIXCommandError {
            guard !childReaped else { throw error }
            let reaped = terminateAndReap(child, status: &status,
                                          output: &output, tooLarge: &outputTooLarge)
            guard reaped else { throw POSIXCommandError.childNotReaped(error.message) }
            if case .timedOut = error { throw POSIXCommandError.timedOut(childReaped: true) }
            throw error
        } catch {
            guard !childReaped else { throw error }
            let reaped = terminateAndReap(child, status: &status,
                                          output: &output, tooLarge: &outputTooLarge)
            guard reaped else { throw POSIXCommandError.childNotReaped(error.localizedDescription) }
            throw error
        }
    }

    internal func spawn(arguments: [String], inheritedFence: Int32?) throws -> RunningPOSIXCommand {
        guard !executable.isEmpty, !executable.contains("\0"),
              arguments.allSatisfy({ !$0.contains("\0") }) else {
            throw POSIXCommandError.spawn("invalid command text")
        }

        var pipeDescriptors = [Int32](repeating: -1, count: 2)
        guard pipe(&pipeDescriptors) == 0 else {
            throw POSIXCommandError.spawn("pipe errno \(errno)")
        }
        let outputRead = pipeDescriptors[0]
        let outputWrite = pipeDescriptors[1]
        do {
            try setCloseOnExec(outputRead)
            try setCloseOnExec(outputWrite)
            try setNonBlocking(outputRead)
        } catch {
            close(outputRead); close(outputWrite)
            throw error
        }

        var fileActions: posix_spawn_file_actions_t? = nil
        guard posix_spawn_file_actions_init(&fileActions) == 0 else {
            close(outputRead); close(outputWrite)
            throw POSIXCommandError.spawn("file-action initialization failed")
        }
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        var actionResult = posix_spawn_file_actions_adddup2(&fileActions, outputWrite, STDOUT_FILENO)
        if actionResult == 0 {
            actionResult = posix_spawn_file_actions_adddup2(&fileActions, outputWrite, STDERR_FILENO)
        }
        if actionResult == 0 {
            actionResult = posix_spawn_file_actions_addclose(&fileActions, outputRead)
        }
        if actionResult == 0 {
            actionResult = posix_spawn_file_actions_addclose(&fileActions, outputWrite)
        }

        var standardInput: Int32 = -1
        if let inheritedFence {
            guard inheritedFence >= 0 else {
                close(outputRead); close(outputWrite)
                throw POSIXCommandError.spawn("invalid inherited fence")
            }
            if actionResult == 0 {
                actionResult = posix_spawn_file_actions_adddup2(&fileActions, inheritedFence, STDIN_FILENO)
            }
            if actionResult == 0, inheritedFence != STDIN_FILENO {
                actionResult = posix_spawn_file_actions_addclose(&fileActions, inheritedFence)
            }
        } else {
            standardInput = open("/dev/null", O_RDONLY | O_CLOEXEC)
            guard standardInput >= 0 else {
                close(outputRead); close(outputWrite)
                throw POSIXCommandError.spawn("open stdin errno \(errno)")
            }
            if actionResult == 0 {
                actionResult = posix_spawn_file_actions_adddup2(&fileActions, standardInput, STDIN_FILENO)
            }
            if actionResult == 0, standardInput != STDIN_FILENO {
                actionResult = posix_spawn_file_actions_addclose(&fileActions, standardInput)
            }
        }

        if actionResult != 0 {
            if standardInput >= 0 { close(standardInput) }
            close(outputRead); close(outputWrite)
            throw POSIXCommandError.spawn("file-action errno \(actionResult)")
        }

        var attributes: posix_spawnattr_t? = nil
        guard posix_spawnattr_init(&attributes) == 0 else {
            if standardInput >= 0 { close(standardInput) }
            close(outputRead); close(outputWrite)
            throw POSIXCommandError.spawn("attribute initialization failed")
        }
        defer { posix_spawnattr_destroy(&attributes) }

        var processID: pid_t = 0
        let allArguments = [executable] + arguments
        let result = Self.withCStringVector(allArguments) { argv in
            Self.withCStringVector(Self.environment) { environment in
                posix_spawn(&processID, executable, &fileActions, &attributes, argv, environment)
            }
        }

        if standardInput >= 0 { close(standardInput) }
        guard result == 0 else {
            close(outputRead); close(outputWrite)
            throw POSIXCommandError.spawn("posix_spawn errno \(result)")
        }

        close(outputWrite)
        return RunningPOSIXCommand(pid: processID, outputDescriptor: outputRead)
    }

    private func terminateAndReap(_ child: RunningPOSIXCommand,
                                   status: inout Int32,
                                   output: inout Data,
                                   tooLarge: inout Bool) -> Bool {
        let killFailed = syscalls.sendSignal(child.pid, SIGKILL) != 0 && errno != ESRCH

        let deadline = DispatchTime.now().uptimeNanoseconds +
            UInt64(Self.finalDrainSeconds * 1_000_000_000)
        while DispatchTime.now().uptimeNanoseconds < deadline {
            let waited = syscalls.waitForProcess(child.pid, &status, WNOHANG)
            if waited == child.pid {
                _ = try? drain(child.outputDescriptor, into: &output, tooLarge: &tooLarge)
                return true
            }
            if waited < 0 {
                if errno == EINTR { continue }
                if errno == ECHILD { return true }
                return false
            }
            _ = try? drain(child.outputDescriptor, into: &output, tooLarge: &tooLarge)
            let waitMilliseconds = millisecondsUntil(deadline: deadline, maximum: 10)
            if waitMilliseconds > 0 {
                _ = try? waitForOutput(child.outputDescriptor, milliseconds: waitMilliseconds)
            }
            if killFailed { Thread.sleep(forTimeInterval: 0.001) }
        }
        return false
    }

    private func drain(_ descriptor: Int32, into output: inout Data,
                       tooLarge: inout Bool) throws -> Bool {
        var buffer = [UInt8](repeating: 0, count: 4_096)
        for _ in 0..<16 {
            let count = buffer.withUnsafeMutableBytes { bytes -> Int in
                guard let baseAddress = bytes.baseAddress else { return 0 }
                return Darwin.read(descriptor, baseAddress, bytes.count)
            }
            if count > 0 {
                let remaining = max(0, Self.maxOutputBytes - output.count)
                if remaining > 0 { output.append(contentsOf: buffer.prefix(min(count, remaining))) }
                if count > remaining { tooLarge = true }
                continue
            }
            if count == 0 { return true }
            if errno == EINTR { continue }
            if errno == EAGAIN || errno == EWOULDBLOCK { return false }
            throw POSIXCommandError.io("read errno \(errno)")
        }
        return false
    }

    private func finishDrain(_ descriptor: Int32, into output: inout Data,
                             tooLarge: inout Bool) throws {
        let deadline = DispatchTime.now().uptimeNanoseconds +
            UInt64(Self.finalDrainSeconds * 1_000_000_000)
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if try drain(descriptor, into: &output, tooLarge: &tooLarge) { return }
            let waitMilliseconds = millisecondsUntil(deadline: deadline, maximum: 10)
            guard waitMilliseconds > 0 else { return }
            let hungUp = try waitForOutput(descriptor, milliseconds: waitMilliseconds)
            if hungUp { Thread.sleep(forTimeInterval: 0.005) }
        }
    }

    private func millisecondsUntil(deadline: UInt64, maximum: Int32) -> Int32 {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now < deadline else { return 0 }
        let remaining = deadline - now
        let requested = min(remaining, UInt64(maximum) * 1_000_000)
        return max(1, Int32((requested + 999_999) / 1_000_000))
    }

    private func waitForOutput(_ descriptor: Int32, milliseconds: Int32) throws -> Bool {
        var descriptorEvents = pollfd(fd: descriptor,
                                      events: Int16(POLLIN | POLLHUP | POLLERR),
                                      revents: 0)
        let result = Darwin.poll(&descriptorEvents, 1, milliseconds)
        guard result >= 0 || errno == EINTR else {
            throw POSIXCommandError.io("poll errno \(errno)")
        }
        return result > 0 && descriptorEvents.revents & Int16(POLLHUP) != 0
    }

    private func setCloseOnExec(_ descriptor: Int32) throws {
        let flags = fcntl(descriptor, F_GETFD)
        guard flags >= 0, fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) >= 0 else {
            throw POSIXCommandError.spawn("fcntl errno \(errno)")
        }
    }

    private func setNonBlocking(_ descriptor: Int32) throws {
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) >= 0 else {
            throw POSIXCommandError.spawn("fcntl errno \(errno)")
        }
    }

    private static func withCStringVector<T>(_ values: [String],
                                             _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> T) rethrows -> T {
        let allocations = values.map { strdup($0)! }
        defer { allocations.forEach { free($0) } }
        var pointers = allocations.map { Optional($0) }
        pointers.append(nil)
        return try pointers.withUnsafeMutableBufferPointer { buffer in
            try body(buffer.baseAddress!)
        }
    }
}
