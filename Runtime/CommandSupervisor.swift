import Foundation
import Darwin

/// Runs only at the invoking user's privilege, in a distinct process group.
/// The GUI/helper never receives command arguments or an execution capability.
public enum CommandSupervisor {
    public static func run(arguments: [String], heartbeat: () -> Void) throws -> Int32 {
        guard !arguments.isEmpty else { throw ControlError.invalid }
        var attributes: posix_spawnattr_t?
        guard posix_spawnattr_init(&attributes) == 0 else { throw ControlError.unavailable }
        defer { posix_spawnattr_destroy(&attributes) }
        var empty = sigset_t(); sigemptyset(&empty)
        var defaults = sigset_t(); sigemptyset(&defaults)
        for value in [SIGINT, SIGTERM, SIGHUP, SIGQUIT, SIGTSTP, SIGTTIN, SIGTTOU, SIGPIPE] { sigaddset(&defaults, value) }
        guard posix_spawnattr_setsigmask(&attributes, &empty) == 0,
              posix_spawnattr_setsigdefault(&attributes, &defaults) == 0,
              posix_spawnattr_setpgroup(&attributes, 0) == 0,
              posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_START_SUSPENDED)) == 0 else {
            throw ControlError.unavailable
        }
        var argv = arguments.map { strdup($0) } + [nil]
        var envp = ProcessInfo.processInfo.environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { for p in argv { free(p) }; for p in envp { free(p) } }
        var pid: pid_t = 0
        let result = posix_spawnp(&pid, arguments[0], nil, &attributes, &argv, &envp)
        guard result == 0 else { return result == ENOENT ? 127 : 126 }
        let child = pid
        let signalQueue = DispatchQueue(label: "com.lidpilot.command-signals")
        var sources: [DispatchSourceSignal] = []
        for value in [SIGINT, SIGTERM, SIGHUP, SIGQUIT] {
            signal(value, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: value, queue: signalQueue)
            source.setEventHandler { kill(-child, value) }
            source.resume(); sources.append(source)
        }
        signal(SIGTTOU, SIG_IGN)
        let foreground = tcgetpgrp(STDIN_FILENO)
        let ownsTerminal = isatty(STDIN_FILENO) == 1 && foreground == getpgrp()
        if ownsTerminal { _ = tcsetpgrp(STDIN_FILENO, child) }
        kill(-child, SIGCONT)
        defer {
            if ownsTerminal { _ = tcsetpgrp(STDIN_FILENO, foreground) }
            for source in sources { source.cancel() }
            for value in [SIGINT, SIGTERM, SIGHUP, SIGQUIT, SIGTTOU] { signal(value, SIG_DFL) }
        }
        var exitStatus: Int32?
        var lastHeartbeat = ProcessInfo.processInfo.systemUptime
        while true {
            if exitStatus == nil {
                var status: Int32 = 0
                let waited = waitpid(child, &status, WNOHANG | WUNTRACED)
                if waited == child {
                    if status & 0xff == 0x7f {
                        // Give the shell its terminal back before suspending this
                        // wrapper; fg resumes both the supervisor and its group.
                        if ownsTerminal { _ = tcsetpgrp(STDIN_FILENO, foreground) }
                        raise(SIGSTOP)
                        if ownsTerminal { _ = tcsetpgrp(STDIN_FILENO, child) }
                        kill(-child, SIGCONT)
                    } else {
                        exitStatus = status & 0x7f == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
                    }
                } else if waited < 0, errno != EINTR { throw ControlError.unavailable }
            }
            if let exitStatus, kill(-child, 0) != 0, errno == ESRCH { return exitStatus }
            if ProcessInfo.processInfo.systemUptime - lastHeartbeat >= 10 {
                heartbeat(); lastHeartbeat = ProcessInfo.processInfo.systemUptime
            }
            usleep(100_000)
        }
    }
}
