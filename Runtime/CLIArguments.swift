import Foundation
import LidPilotCore

public enum CLICommand: Equatable, Sendable {
    case status, start(Mode, Double), stop, diagnostics(String), run(Mode, Double, [String])
    case hook(WorkloadSource, String), configureHooks(Bool, WorkloadSource, String, String)
    case install(String), uninstall(String), arm, disarm, help

    public static func parse(_ arguments: [String]) throws -> Self {
        var args = arguments
        guard let verb = args.first else { return .help }
        args.removeFirst()
        func options(_ allowed: Set<String>) throws -> [String: String] {
            var result: [String: String] = [:]
            var i = 0
            while i < args.count {
                let key = args[i]
                if key == "--json", allowed.contains(key), result[key] == nil {
                    result[key] = "true"; i += 1; continue
                }
                guard allowed.contains(key), result[key] == nil, i + 1 < args.count else { throw ControlError.invalid }
                result[key] = args[i + 1]; i += 2
            }
            return result
        }
        switch verb {
        case "help", "--help", "-h": guard args.isEmpty else { throw ControlError.invalid }; return .help
        case "status": _ = try options(["--json"]); return .status
        case "stop": _ = try options(["--json"]); return .stop
        case "start":
            let values = try options(["--mode", "--for", "--json"])
            guard let mode = Mode(rawValue: values["--mode"] ?? ""), let raw = values["--for"] else { throw ControlError.invalid }
            return .start(mode, try duration(raw))
        case "diagnostics":
            let values = try options(["--output"])
            guard let path = values["--output"], !path.isEmpty else { throw ControlError.invalid }
            return .diagnostics(path)
        case "run":
            guard let separator = args.firstIndex(of: "--"), separator + 1 < args.count else { throw ControlError.invalid }
            let command = Array(args[(separator + 1)...]); args = Array(args[..<separator])
            let values = try options(["--mode", "--for"])
            guard let mode = Mode(rawValue: values["--mode"] ?? "closed") else { throw ControlError.invalid }
            let maximum = try values["--for"].map(duration) ?? 28_800
            guard (60...86_400).contains(maximum) else { throw ControlError.invalid }
            return .run(mode, maximum, command)
        case "tasks":
            if args == ["arm"] { return .arm }
            if args == ["disarm"] { return .disarm }
            throw ControlError.invalid
        case "hook":
            guard let sourceName = args.first, let source = WorkloadSource(rawValue: sourceName), source != .command else { throw ControlError.invalid }
            args.removeFirst()
            let values = try options(["--adapter-version"])
            guard let version = values["--adapter-version"], HookSignal.versions[source] == version else { throw ControlError.invalid }
            return .hook(source, version)
        case "hooks":
            guard args.count >= 2, ["install", "remove"].contains(args[0]),
                  let source = WorkloadSource(rawValue: args[1]), source != .command else { throw ControlError.invalid }
            let install = args[0] == "install"; args.removeFirst(2)
            let values = try options(["--config", "--adapter-version"])
            guard let path = values["--config"], let version = values["--adapter-version"],
                  HookSignal.versions[source] == version else { throw ControlError.invalid }
            return .configureHooks(install, source, version, path)
        case "install", "uninstall":
            let values = try options(["--directory"])
            guard let directory = values["--directory"], !directory.isEmpty else { throw ControlError.invalid }
            return verb == "install" ? .install(directory) : .uninstall(directory)
        default: throw ControlError.invalid
        }
    }

    public static func duration(_ raw: String) throws -> Double {
        guard let suffix = raw.last, let multiplier = ["s": 1.0, "m": 60, "h": 3600, "d": 86_400][String(suffix)],
              let value = Double(raw.dropLast()), value.isFinite, value > 0 else { throw ControlError.invalid }
        let seconds = value * multiplier
        guard (1...604_800).contains(seconds) else { throw ControlError.invalid }
        return seconds
    }

    public static let helpText = """
    LidPilot — local session control (enable CLI in the running app first)
      lidpilot status --json
      lidpilot start --mode display|smart|closed --for 2h
      lidpilot stop
      lidpilot diagnostics --output ./lidpilot-report.json
      lidpilot run --mode closed [--for 8h] -- <command> [arguments...]
      lidpilot tasks arm|disarm
      lidpilot install|uninstall --directory <existing user-owned bin directory>
      lidpilot hooks install|remove codex|claude --config <JSON file> --adapter-version <version>

    Hooks: Codex 0.154.0; Claude Code 2.1.112. Hook installation never arms tasks.
    Run preserves command output/status and waits for its process group. Children
    that detach into another process group/session are outside its scope.
    Safety may end protection while a command continues; LidPilot does not kill work.
    Exit codes: 0 confirmed, 64 input, 69 app unavailable, 73 conflict,
                75 unverified, 77 approval required, 78 blocked.
    """
}
