import Foundation
import Darwin
import LidPilotCore
import LidPilotRuntime

enum CLI {
    static func main() -> Int32 {
        var arguments = Array(CommandLine.arguments.dropFirst())
        #if DEBUG
        var channel = "development"
        if arguments.first == "--preview" { channel = "preview"; arguments.removeFirst() }
        #else
        let channel = "production"
        #endif
        let endpoint = LocalControl.path(channel: channel)
        let isHook = arguments.first == "hook"
        if isHook {
            // Neutral JSON is valid for both providers, including Codex Stop.
            // Never print payloads, grant approval, block or continue an agent.
            defer { print("{}") }
            if case let .hook(source, version) = try? CLICommand.parse(arguments),
               let input = boundedInput(),
               let signal = try? HookSignal.decodeProvider(input, source: source, version: version) {
                _ = try? LocalControl.send(ControlRequest(.hook, hook: signal), path: endpoint, timeout: 0.5)
            }
            return 0
        }
        do {
            let command = try CLICommand.parse(arguments)
            switch command {
            case .help: print(CLICommand.helpText); return 0
            case .status: return try output(LocalControl.send(ControlRequest(.status), path: endpoint))
            case .start(let mode, let seconds): return try output(LocalControl.send(ControlRequest(.start, mode: mode, seconds: seconds), path: endpoint))
            case .stop: return try output(LocalControl.send(ControlRequest(.stop), path: endpoint))
            case .arm: return try output(LocalControl.send(ControlRequest(.arm), path: endpoint))
            case .disarm: return try output(LocalControl.send(ControlRequest(.disarm), path: endpoint))
            case .diagnostics(let path):
                let reply = try LocalControl.send(ControlRequest(.diagnostics), path: endpoint)
                guard reply.code == .success else { return try output(reply) }
                try CLIFileOperations.export(reply.encoded(), to: URL(fileURLWithPath: path))
                print("Saved local diagnostics to \(path)"); return 0
            case .run(let mode, let maximum, let command): return try run(mode: mode, maximum: maximum, command: command, endpoint: endpoint)
            case .install(let directory):
                try CLIFileOperations.install(executable: executable, directory: URL(fileURLWithPath: directory))
                print("Installed lidpilot. No shell configuration was changed."); return 0
            case .uninstall(let directory):
                try CLIFileOperations.install(executable: executable, directory: URL(fileURLWithPath: directory), remove: true)
                print("Removed this lidpilot symlink."); return 0
            case .configureHooks(let install, let source, let version, let path):
                try CLIFileOperations.configureHooks(at: URL(fileURLWithPath: path), source: source, version: version, executable: executable, install: install)
                print(install ? "Installed LidPilot hooks. Arm task hooks in the app when ready; existing handlers were preserved." : "Removed LidPilot hooks; other settings were preserved.")
                return 0
            case .hook: return 0
            }
        } catch {
            let code: ControlCode
            switch error {
            case ControlError.invalid, ControlError.oversized, is DecodingError: code = .invalidInput
            case ControlError.busy, ControlError.unsafePath: code = .conflict
            case ControlError.timedOut: code = .unverified
            default: code = (error as NSError).domain == "com.lidpilot.cli" ? .conflict : .unavailable
            }
            let reply = ControlReply(code: code, message: error.localizedDescription)
            if let data = try? reply.encoded() { FileHandle.standardError.write(data + Data([10])) }
            return Int32(code.rawValue)
        }
    }

    static var executable: URL {
        // Bundle.main is a tool on CLI invocation. Resolve PATH symlinks once for
        // install/remove identity, without rewriting the invoking shell's PATH.
        (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
            .standardizedFileURL.resolvingSymlinksInPath()
    }
    static func output(_ reply: ControlReply) throws -> Int32 {
        FileHandle.standardOutput.write(try reply.encoded() + Data([10]))
        return Int32(reply.code.rawValue)
    }
    static func boundedInput() -> Data? {
        var data = Data()
        let end = ProcessInfo.processInfo.systemUptime + 0.75
        var bytes = [UInt8](repeating: 0, count: 8192)
        while ProcessInfo.processInfo.systemUptime < end {
            var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, 50)
            if ready < 0, errno == EINTR { continue }
            if ready <= 0 { continue }
            let count = Darwin.read(STDIN_FILENO, &bytes, bytes.count)
            if count == 0 { return data }
            if count < 0 { return nil }
            data.append(contentsOf: bytes.prefix(count))
            if data.count > 1_048_576 { return nil }
        }
        return nil
    }
    static func run(mode: Mode, maximum: Double, command: [String], endpoint: String) throws -> Int32 {
        let id = UUID().uuidString
        var sequence: UInt64 = 1
        func event(_ state: WorkloadState, exit: Int32? = nil) -> WorkloadEvent {
            defer { sequence += 1 }
            return WorkloadEvent(eventID: UUID().uuidString, source: .command, adapterVersion: "1",
                sessionID: id, turnID: id, taskID: nil, sequence: sequence, timestamp: Date(), state: state, exitCode: exit.map(Int.init))
        }
        let start = try LocalControl.send(ControlRequest(.taskStart, mode: mode, seconds: maximum, event: event(.working)), path: endpoint)
        guard start.code == .success else {
            FileHandle.standardError.write(try start.encoded() + Data([10])); return Int32(start.code.rawValue)
        }
        var warned = false
        let status: Int32
        do {
            status = try CommandSupervisor.run(arguments: command) {
                let reply = try? LocalControl.send(ControlRequest(.taskEvent, mode: mode, event: event(.working)), path: endpoint, timeout: 2)
                if reply?.code != .success, !warned {
                    FileHandle.standardError.write(Data("LidPilot: keep-awake protection is no longer confirmed; the command continues.\n".utf8))
                    warned = true
                }
            }
        } catch {
            _ = try? LocalControl.send(ControlRequest(.taskEvent, mode: mode, event: event(.unknown)), path: endpoint, timeout: 2)
            throw error
        }
        let finish = try? LocalControl.send(ControlRequest(.taskEvent, mode: mode,
            event: event(status == 0 ? .finished : .failed, exit: status)), path: endpoint, timeout: 2)
        if finish?.code != .success {
            FileHandle.standardError.write(Data("LidPilot: command ended; cleanup is not yet confirmed. Check the app.\n".utf8))
        }
        return status
    }
}

exit(CLI.main())
