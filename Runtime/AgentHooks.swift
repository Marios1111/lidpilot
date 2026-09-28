import Foundation
import LidPilotCore

/// An allowlist projection of provider stdin. Everything else (including prompts,
/// tool arguments, paths and transcripts) is discarded before IPC or storage.
public struct HookSignal: Codable, Sendable {
    public let source: WorkloadSource
    public let adapterVersion: String
    public let eventName: String
    public let sessionID: String
    public let turnID: String?
    public let taskID: String?
    public let invocationID: String?
    public let capturedAt: Date
    public let nonce: String

    public init(source: WorkloadSource, adapterVersion: String, eventName: String, sessionID: String,
                turnID: String? = nil, taskID: String? = nil, invocationID: String? = nil,
                capturedAt: Date = Date(), nonce: String = UUID().uuidString) {
        self.source = source; self.adapterVersion = adapterVersion; self.eventName = eventName
        self.sessionID = sessionID; self.turnID = turnID; self.taskID = taskID
        self.invocationID = invocationID; self.capturedAt = capturedAt; self.nonce = nonce
    }

    public static let versions: [WorkloadSource: String] = [.codex: "0.154.0", .claude: "2.1.112"]
    public static func events(for source: WorkloadSource) -> [String] {
        let common = ["SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "SubagentStart", "SubagentStop", "Stop"]
        return common + (source == .codex ? ["Interrupt"] : ["StopFailure", "Notification"])
    }
    static func opaque(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45, 46, 58, 95].contains($0)
        }
    }
    public func validate() throws {
        guard Self.versions[source] == adapterVersion, Self.events(for: source).contains(eventName),
              Self.opaque(sessionID), Self.opaque(nonce), turnID.map(Self.opaque) ?? true,
              taskID.map(Self.opaque) ?? true, invocationID.map(Self.opaque) ?? true,
              capturedAt.timeIntervalSinceReferenceDate.isFinite else { throw ControlError.invalid }
        if eventName == "SubagentStart" || eventName == "SubagentStop" {
            guard taskID != nil else { throw ControlError.invalid }
        }
        if source == .codex, !["SessionStart", "SessionEnd"].contains(eventName), turnID == nil { throw ControlError.invalid }
    }

    public static func decodeProvider(_ data: Data, source: WorkloadSource, version: String, at date: Date = Date()) throws -> Self? {
        guard data.count <= 1_048_576,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = object["hook_event_name"] as? String,
              let session = object["session_id"] as? String else { throw ControlError.invalid }
        // Only a provider's approval/idle notification can change work state.
        if name == "Notification", !["permission_prompt", "idle_prompt"].contains(object["notification_type"] as? String ?? "") { return nil }
        let result = Self(source: source, adapterVersion: version, eventName: name, sessionID: session,
            turnID: object["turn_id"] as? String, taskID: object["agent_id"] as? String,
            invocationID: object["tool_use_id"] as? String, capturedAt: date)
        try result.validate()
        return result
    }
}

/// Provider differences end here. The controller receives the same small, ordered
/// workload event contract as the supervised command wrapper.
public struct HookRouter: Sendable {
    private struct Session: Sendable {
        var turn: String?
        var sequence: UInt64 = 0
        var latest: Date = .distantPast
        var seen = Set<String>()
    }
    private var sessions: [String: Session] = [:]
    public init() {}
    public mutating func reset() { sessions.removeAll() }

    public mutating func events(for signal: HookSignal, workloads: [WorkloadRecord] = [], now: Date = Date()) throws -> [WorkloadEvent] {
        try signal.validate()
        guard (-5...60).contains(now.timeIntervalSince(signal.capturedAt)) else { throw ControlError.invalid }
        let key = signal.source.rawValue + ":" + signal.sessionID
        guard sessions[key] != nil || sessions.count < 128 else { throw ControlError.busy }
        var session = sessions[key] ?? Session()
        guard signal.capturedAt >= session.latest else { return [] }
        let dedup = signal.invocationID.map { signal.eventName + ":" + $0 } ?? signal.nonce
        guard !session.seen.contains(dedup) else { return [] }
        // A bounded event-history window is enough for transport duplicates; the
        // registry retains terminal task tombstones for the whole armed period.
        if session.seen.count >= 512 { session.seen.removeAll() }
        session.seen.insert(dedup)
        session.latest = signal.capturedAt
        defer { sessions[key] = session }
        if signal.eventName == "SessionStart" { return [] }
        if signal.eventName == "SessionEnd" || (signal.eventName == "Interrupt" && signal.taskID == nil) {
            // Disconnect/cancel is unknown, never successful completion. Release
            // every matching child too, even when a final Stop hook was missed.
            return workloads.filter {
                $0.source == signal.source && $0.sessionID == signal.sessionID &&
                (signal.eventName == "SessionEnd" || $0.turnID == signal.turnID) &&
                ![.finished, .failed].contains($0.state)
            }.map { record in
                session.sequence = max(session.sequence, record.sequence) + 1
                return WorkloadEvent(eventID: UUID().uuidString, source: signal.source, adapterVersion: signal.adapterVersion,
                    sessionID: signal.sessionID, turnID: record.turnID, taskID: record.taskID,
                    sequence: session.sequence, timestamp: signal.capturedAt, state: .unknown, exitCode: nil)
            }
        }
        if signal.eventName == "UserPromptSubmit" {
            session.turn = signal.turnID ?? UUID().uuidString
        }
        let knownTaskTurn = signal.taskID.flatMap { taskID in workloads.first {
            $0.source == signal.source && $0.sessionID == signal.sessionID && $0.taskID == taskID
        }?.turnID }
        // Claude does not provide a native main-turn identifier in this adapter
        // version. An uncorrelated late Stop/wait/failure cannot end a newer turn.
        // Keep its last confirmed work state until the bounded missing-event limit.
        if signal.source == .claude, signal.turnID == nil, knownTaskTurn == nil,
           ["Stop", "StopFailure", "PermissionRequest", "Notification"].contains(signal.eventName) { return [] }
        guard let turn = signal.turnID ?? knownTaskTurn ?? session.turn else { return [] }
        let state: WorkloadState
        switch signal.eventName {
        case "UserPromptSubmit", "PreToolUse", "PostToolUse", "SubagentStart": state = .working
        case "PermissionRequest", "Notification": state = .waiting
        case "Stop": state = .idle // A stop hook can still be followed by continuation.
        case "SubagentStop": state = .finished
        case "StopFailure": state = .failed
        case "Interrupt", "SessionEnd": state = .unknown
        default: return []
        }
        session.sequence += 1
        return [WorkloadEvent(eventID: signal.nonce, source: signal.source, adapterVersion: signal.adapterVersion,
            sessionID: signal.sessionID, turnID: turn,
            taskID: signal.taskID,
            sequence: session.sequence, timestamp: signal.capturedAt, state: state, exitCode: nil)]
    }
}

public enum HookConfiguration {
    private static let marker = " # lidpilot-hook-v1"

    /// Returns replacement bytes so callers can preview/test edits and perform a
    /// guarded atomic save. Unrelated hook handlers and all other keys survive.
    public static func updated(_ data: Data?, source: WorkloadSource, version: String, executable: String, install: Bool) throws -> Data {
        guard HookSignal.versions[source] == version, executable.hasPrefix("/"), !executable.contains("\n"),
              !executable.contains("\r"), !executable.contains("\0"), (data?.count ?? 0) <= 1_048_576 else { throw ControlError.invalid }
        var document: [String: Any]
        if let data {
            guard let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ControlError.invalid }
            document = decoded
        } else { document = [:] }
        if let existing = document["hooks"], !(existing is [String: Any]) { throw ControlError.invalid }
        var hooks = document["hooks"] as? [String: Any] ?? [:]
        let quoted = "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let command = "\(quoted) hook \(source.rawValue) --adapter-version \(version)\(marker)"
        for name in HookSignal.events(for: source) {
            if let existing = hooks[name], !(existing is [[String: Any]]) { throw ControlError.invalid }
            var groups = hooks[name] as? [[String: Any]] ?? []
            groups = try groups.compactMap { group in
                guard let entries = group["hooks"] as? [[String: Any]] else { throw ControlError.invalid }
                let retained = entries.filter { !isOurs($0, source: source) }
                if retained.isEmpty { return nil }
                var updated = group; updated["hooks"] = retained; return updated
            }
            if install { groups.append(["hooks": [["type": "command", "command": command, "timeout": 2]]]) }
            if groups.isEmpty { hooks.removeValue(forKey: name) } else { hooks[name] = groups }
        }
        if hooks.isEmpty { document.removeValue(forKey: "hooks") } else { document["hooks"] = hooks }
        return try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
    }

    private static func isOurs(_ handler: [String: Any], source: WorkloadSource) -> Bool {
        guard handler["type"] as? String == "command", let command = handler["command"] as? String else { return false }
        return command.hasSuffix(marker) && command.contains(" hook \(source.rawValue) --adapter-version ")
    }
}
