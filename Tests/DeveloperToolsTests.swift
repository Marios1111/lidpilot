import Foundation
import Darwin
import Testing
import LidPilotCore
@testable import LidPilotRuntime

struct DeveloperToolsTests {
    @Test func parserRequiresBoundedDurationsAndNeverAcceptsArbitraryControlCommands() throws {
        #expect(try CLICommand.parse(["start", "--mode", "display", "--for", "2h"]) == .start(.display, 7200))
        #expect(try CLICommand.parse(["run", "--mode", "closed", "--", "/bin/echo", "hello world"]) == .run(.closed, 28_800, ["/bin/echo", "hello world"]))
        for args in [["start", "--mode", "display"], ["start", "--mode", "display", "--for", "nanm"],
                     ["stop", "--command", "something"], ["status", "--json", "--json"], ["run", "--"]] {
            #expect(throws: (any Error).self) { try CLICommand.parse(args) }
        }
    }

    @Test func hookProjectionDiscardsAllContentAndRejectsPathsAsIdentifiers() throws {
        let raw = Data(#"{"hook_event_name":"UserPromptSubmit","session_id":"session","turn_id":"turn","prompt":"PRIVATE PROMPT","cwd":"/private/project","transcript_path":"/secret/transcript","tool_input":{"password":"secret"}}"#.utf8)
        let signal = try #require(try HookSignal.decodeProvider(raw, source: .codex, version: "0.154.0"))
        let encoded = String(decoding: try JSONEncoder().encode(signal), as: UTF8.self)
        #expect(!encoded.contains("PRIVATE") && !encoded.contains("password") && !encoded.contains("/secret") && !encoded.contains("cwd"))
        let bad = Data(#"{"hook_event_name":"UserPromptSubmit","session_id":"/private/project","turn_id":"turn"}"#.utf8)
        #expect(throws: (any Error).self) { try HookSignal.decodeProvider(bad, source: .codex, version: "0.154.0") }
        #expect(throws: (any Error).self) { try HookSignal.decodeProvider(raw, source: .codex, version: "0.153.0") }
    }

    @Test func hookLifecycleNeverTreatsSessionOpenOrStopAsFinalTaskSuccess() throws {
        var router = HookRouter()
        let now = Date()
        func signal(_ name: String, turn: String? = nil, task: String? = nil, nonce: String = UUID().uuidString) -> HookSignal {
            HookSignal(source: .codex, adapterVersion: "0.154.0", eventName: name, sessionID: "s", turnID: turn, taskID: task, capturedAt: now, nonce: nonce)
        }
        #expect(try router.events(for: signal("SessionStart"), now: now).isEmpty)
        let start = signal("UserPromptSubmit", turn: "turn", nonce: "event-1")
        #expect(try router.events(for: start, now: now).first?.state == .working)
        #expect(try router.events(for: start, now: now).isEmpty)
        #expect(try router.events(for: signal("PermissionRequest", turn: "turn"), now: now).first?.state == .waiting)
        #expect(try router.events(for: signal("SubagentStart", turn: "turn", task: "child"), now: now).first?.taskID == "child")
        #expect(try router.events(for: signal("Stop", turn: "turn"), now: now).first?.state == .idle)
        #expect(try router.events(for: signal("PreToolUse", turn: "turn"), now: now).first?.state == .working)
        #expect(try router.events(for: signal("SubagentStop", turn: "turn", task: "child"), now: now).first?.state == .finished)
    }

    @Test func hookConfigInstallIsIdempotentAndRemovalPreservesOtherHandlers() throws {
        let original = Data(#"{"theme":"light","hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"my-existing-hook"}]}]}}"#.utf8)
        let first = try HookConfiguration.updated(original, source: .claude, version: "2.1.112", executable: "/Applications/My App's.app/Contents/MacOS/lidpilot", install: true)
        let second = try HookConfiguration.updated(first, source: .claude, version: "2.1.112", executable: "/Applications/My App's.app/Contents/MacOS/lidpilot", install: true)
        #expect(first == second)
        let removed = try HookConfiguration.updated(second, source: .claude, version: "2.1.112", executable: "/anywhere/lidpilot", install: false)
        let dictionary = try #require(try JSONSerialization.jsonObject(with: removed) as? NSDictionary)
        #expect(dictionary == (try JSONSerialization.jsonObject(with: original) as? NSDictionary))
        #expect(String(decoding: first, as: UTF8.self).contains("my-existing-hook"))
    }

    @Test func uncorrelatedClaudeStopCannotEndNewerTurnAndDisconnectReleasesChildren() throws {
        var router = HookRouter(), registry = WorkloadRegistry()
        let clock = ClockSample(continuousSeconds: 100, wallDate: Date(), bootID: "hooks-test")
        func signal(_ name: String, task: String? = nil) -> HookSignal {
            HookSignal(source: .claude, adapterVersion: "2.1.112", eventName: name, sessionID: "session", taskID: task, capturedAt: clock.wallDate)
        }
        let first = try #require(try router.events(for: signal("UserPromptSubmit"), now: clock.wallDate).first)
        try registry.apply(first, mode: .display, at: clock)
        let child = try #require(try router.events(for: signal("SubagentStart", task: "child"), now: clock.wallDate).first)
        try registry.apply(child, mode: .display, at: clock)
        let second = try #require(try router.events(for: signal("UserPromptSubmit"), now: clock.wallDate).first)
        try registry.apply(second, mode: .display, at: clock)
        #expect(first.turnID != second.turnID)
        #expect(try router.events(for: signal("Stop"), workloads: registry.records, now: clock.wallDate).isEmpty)
        let finishedChild = try #require(try router.events(for: signal("SubagentStop", task: "child"), workloads: registry.records, now: clock.wallDate).first)
        #expect(finishedChild.turnID == first.turnID)
        let disconnected = try router.events(for: signal("SessionEnd"), workloads: registry.records, now: clock.wallDate)
        #expect(disconnected.count == 3 && disconnected.allSatisfy { $0.state == .unknown })
    }

    @Test func incompleteSocketFrameHasAnAbsoluteDeadline() throws {
        var sockets: [Int32] = [0, 0]
        #expect(socketpair(AF_UNIX, SOCK_STREAM, 0, &sockets) == 0)
        defer { close(sockets[0]); close(sockets[1]) }
        var header: UInt32 = UInt32(20).bigEndian
        _ = withUnsafeBytes(of: &header) { Darwin.write(sockets[0], $0.baseAddress!, $0.count) }
        let began = ProcessInfo.processInfo.systemUptime
        #expect(throws: ControlError.timedOut) { try LocalControl.readFrame(sockets[1], timeout: 0.1) }
        #expect(ProcessInfo.processInfo.systemUptime - began < 1)
    }

    @Test func exportAndInstallRefuseToOverwriteAndRemovalChecksOwnership() throws {
        let directory = URL(fileURLWithPath: "/private/tmp/lidpilot-cli-files-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("report.json")
        try CLIFileOperations.export(Data("report".utf8), to: target)
        #expect(throws: (any Error).self) { try CLIFileOperations.export(Data("overwritten".utf8), to: target) }
        #expect(try Data(contentsOf: target) == Data("report".utf8))
        try CLIFileOperations.install(executable: URL(fileURLWithPath: "/bin/echo"), directory: directory)
        #expect(throws: (any Error).self) { try CLIFileOperations.install(executable: URL(fileURLWithPath: "/bin/cat"), directory: directory) }
        #expect(throws: (any Error).self) { try CLIFileOperations.install(executable: URL(fileURLWithPath: "/bin/cat"), directory: directory, remove: true) }
        try CLIFileOperations.install(executable: URL(fileURLWithPath: "/bin/echo"), directory: directory, remove: true)
    }

    @Test func socketRoundTripIsBoundedAndRejectsUnsafeEndpointDirectory() async throws {
        let directory = "/private/tmp/lp-socket-\(UUID().uuidString)"
        let path = directory + "/control.sock"
        let server = LocalControlServer { request in ControlReply(code: .success, message: request.operation.rawValue) }
        try server.start(path: path)
        defer { server.stop(); try? FileManager.default.removeItem(atPath: directory) }
        let response = try await Task.detached { try LocalControl.send(ControlRequest(.status), path: path, timeout: 2) }.value
        #expect(response.code == .success && response.message == "status")
        #expect(throws: (any Error).self) { try LocalControlServer { _ in ControlReply(code: .success, message: "wrong") }.start(path: path) }
        chmod(directory, 0o755)
        #expect(throws: (any Error).self) { try LocalControl.send(ControlRequest(.status), path: path) }
        chmod(directory, 0o700)
    }

    @Test func commandSupervisorPreservesStatusAndWaitsForKnownChildren() throws {
        #expect(try CommandSupervisor.run(arguments: ["/bin/sh", "-c", "exit 23"], heartbeat: {}) == 23)
        #expect(try CommandSupervisor.run(arguments: ["/a/missing/lidpilot-test-command"], heartbeat: {}) == 127)
        let start = ProcessInfo.processInfo.systemUptime
        #expect(try CommandSupervisor.run(arguments: ["/bin/sh", "-c", "sleep 0.4 & exit 0"], heartbeat: {}) == 0)
        #expect(ProcessInfo.processInfo.systemUptime - start >= 0.35)
    }
}
