import Foundation

public enum WorkloadSource: String, Codable, Sendable {
    case command
    case claude
    case codex
}

public enum WorkloadState: String, Codable, Sendable {
    case working
    case waiting
    case idle
    case finished
    case failed
    case unknown
}

public struct WorkloadEvent: Codable, Equatable, Sendable {
    public let eventID: String
    public let source: WorkloadSource
    public let adapterVersion: String
    public let sessionID: String
    public let turnID: String
    public let taskID: String?
    public let sequence: UInt64
    public let timestamp: Date
    public let state: WorkloadState
    public let exitCode: Int?

    public init(
        eventID: String,
        source: WorkloadSource,
        adapterVersion: String,
        sessionID: String,
        turnID: String,
        taskID: String? = nil,
        sequence: UInt64,
        timestamp: Date,
        state: WorkloadState,
        exitCode: Int? = nil
    ) {
        self.eventID = eventID
        self.source = source
        self.adapterVersion = adapterVersion
        self.sessionID = sessionID
        self.turnID = turnID
        self.taskID = taskID
        self.sequence = sequence
        self.timestamp = timestamp
        self.state = state
        self.exitCode = exitCode
    }
}

public enum WorkloadError: Error, Equatable, Sendable, LocalizedError {
    case invalidEvent
    case invalidOptions
    case invalidClock
    case invalidDeadline
    case eventTimestampOutOfRange
    case identityCapacityReached
    case recordCapacityReached

    public var errorDescription: String? {
        switch self {
        case .invalidEvent:
            "The workload event contains invalid or unsupported metadata."
        case .invalidOptions:
            "Workload timing options are outside their supported ranges."
        case .invalidClock:
            "The workload clock sample is invalid."
        case .invalidDeadline:
            "A safe workload deadline could not be created."
        case .eventTimestampOutOfRange:
            "The workload event is more than five seconds in the future or over sixty seconds old."
        case .identityCapacityReached:
            "Workload identity capacity is full. Stop and re-arm workload tracking to continue."
        case .recordCapacityReached:
            "All workload record slots are active. End a workload or stop and re-arm tracking."
        }
    }
}

public struct WorkloadOptions: Equatable, Sendable {
    public let waitingGrace: Double
    public let settlingInterval: Double
    public let staleAfter: Double
    public let maximumDuration: Double

    public init(
        waitingGrace: Double = 120,
        settlingInterval: Double = 3,
        staleAfter: Double = 900,
        maximumDuration: Double = 28_800
    ) {
        self.waitingGrace = waitingGrace
        self.settlingInterval = settlingInterval
        self.staleAfter = staleAfter
        self.maximumDuration = maximumDuration
    }

    public func validate() throws {
        guard waitingGrace.isFinite, (30...600).contains(waitingGrace),
              settlingInterval.isFinite, (1...15).contains(settlingInterval),
              staleAfter.isFinite, (60...1_800).contains(staleAfter),
              maximumDuration.isFinite, (60...86_400).contains(maximumDuration) else {
            throw WorkloadError.invalidOptions
        }
    }
}

public struct WorkloadRecord: Codable, Equatable, Identifiable, Sendable {
    public let source: WorkloadSource
    public let sessionID: String
    public let turnID: String
    public let taskID: String?
    public let mode: Mode
    public let state: WorkloadState
    public let lastEventID: String
    public let sequence: UInt64
    public let startedAt: ClockSample
    public let updatedAt: ClockSample
    public let hardDeadline: SessionDeadline
    public let holdDeadline: SessionDeadline
    public let exitCode: Int?

    public var id: String {
        Self.identityKey(source: source, sessionID: sessionID, turnID: turnID, taskID: taskID)
    }

    fileprivate init(
        source: WorkloadSource,
        sessionID: String,
        turnID: String,
        taskID: String?,
        mode: Mode,
        state: WorkloadState,
        lastEventID: String,
        sequence: UInt64,
        startedAt: ClockSample,
        updatedAt: ClockSample,
        hardDeadline: SessionDeadline,
        holdDeadline: SessionDeadline,
        exitCode: Int?
    ) {
        self.source = source
        self.sessionID = sessionID
        self.turnID = turnID
        self.taskID = taskID
        self.mode = mode
        self.state = state
        self.lastEventID = lastEventID
        self.sequence = sequence
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.hardDeadline = hardDeadline
        self.holdDeadline = holdDeadline
        self.exitCode = exitCode
    }

    fileprivate func updating(
        mode: Mode,
        state: WorkloadState,
        event: WorkloadEvent,
        at: ClockSample,
        holdDeadline: SessionDeadline
    ) -> Self {
        Self(
            source: source,
            sessionID: sessionID,
            turnID: turnID,
            taskID: taskID,
            mode: mode,
            state: state,
            lastEventID: event.eventID,
            sequence: event.sequence,
            startedAt: startedAt,
            updatedAt: at,
            hardDeadline: hardDeadline,
            holdDeadline: holdDeadline,
            exitCode: event.exitCode
        )
    }

    fileprivate static func identityKey(
        source: WorkloadSource,
        sessionID: String,
        turnID: String,
        taskID: String?
    ) -> String {
        let task = taskID.map { "\($0.utf8.count):\($0)" } ?? "-"
        return "\(source.rawValue):\(sessionID.utf8.count):\(sessionID):\(turnID.utf8.count):\(turnID):\(task)"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case source
        case sessionID
        case turnID
        case taskID
        case mode
        case state
        case lastEventID
        case sequence
        case startedAt
        case updatedAt
        case hardDeadline
        case holdDeadline
        case exitCode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let source = try container.decode(WorkloadSource.self, forKey: .source)
        let sessionID = try container.decode(String.self, forKey: .sessionID)
        let turnID = try container.decode(String.self, forKey: .turnID)
        let taskID = try container.decodeIfPresent(String.self, forKey: .taskID)
        let mode = try container.decode(Mode.self, forKey: .mode)
        let state = try container.decode(WorkloadState.self, forKey: .state)
        let lastEventID = try container.decode(String.self, forKey: .lastEventID)
        let sequence = try container.decode(UInt64.self, forKey: .sequence)
        let startedAt = try container.decode(ClockSample.self, forKey: .startedAt)
        let updatedAt = try container.decode(ClockSample.self, forKey: .updatedAt)
        let hardDeadline = try container.decode(SessionDeadline.self, forKey: .hardDeadline)
        let holdDeadline = try container.decode(SessionDeadline.self, forKey: .holdDeadline)
        let exitCode = try container.decodeIfPresent(Int.self, forKey: .exitCode)

        let hardDuration: Double
        if case let .seconds(seconds) = hardDeadline.duration {
            hardDuration = seconds
        } else {
            throw WorkloadError.invalidDeadline
        }
        let holdDuration: Double
        if case let .seconds(seconds) = holdDeadline.duration {
            holdDuration = seconds
        } else {
            throw WorkloadError.invalidDeadline
        }

        guard Self.isValidOpaqueID(lastEventID, maximumBytes: 128),
              Self.isValidOpaqueID(sessionID, maximumBytes: 128),
              Self.isValidOpaqueID(turnID, maximumBytes: 128),
              taskID.map({ Self.isValidOpaqueID($0, maximumBytes: 128) }) ?? true,
              sequence > 0,
              startedAt.isValid,
              updatedAt.isValid,
              (60...86_400).contains(hardDuration),
              holdDuration.isFinite, holdDuration > 0, holdDuration <= hardDuration,
              hardDeadline.startedAt == startedAt,
              holdDeadline.bootID == startedAt.bootID,
              id == Self.identityKey(source: source, sessionID: sessionID, turnID: turnID, taskID: taskID) else {
            throw WorkloadError.invalidEvent
        }
        try hardDeadline.validate()
        try holdDeadline.validate()

        self.init(
            source: source,
            sessionID: sessionID,
            turnID: turnID,
            taskID: taskID,
            mode: mode,
            state: state,
            lastEventID: lastEventID,
            sequence: sequence,
            startedAt: startedAt,
            updatedAt: updatedAt,
            hardDeadline: hardDeadline,
            holdDeadline: holdDeadline,
            exitCode: exitCode
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(source, forKey: .source)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(turnID, forKey: .turnID)
        try container.encodeIfPresent(taskID, forKey: .taskID)
        try container.encode(mode, forKey: .mode)
        try container.encode(state, forKey: .state)
        try container.encode(lastEventID, forKey: .lastEventID)
        try container.encode(sequence, forKey: .sequence)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(hardDeadline, forKey: .hardDeadline)
        try container.encode(holdDeadline, forKey: .holdDeadline)
        try container.encodeIfPresent(exitCode, forKey: .exitCode)
    }

    fileprivate static func isValidOpaqueID(_ value: String, maximumBytes: Int) -> Bool {
        guard !value.isEmpty, value.utf8.count <= maximumBytes else {
            return false
        }
        return value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte) ||
                byte == 45 || byte == 46 || byte == 58 || byte == 95
        }
    }
}

public struct WorkloadHold: Codable, Equatable, Sendable {
    public let id: String
    public let mode: Mode
    public let deadline: SessionDeadline

    public init(id: String, mode: Mode, deadline: SessionDeadline) {
        self.id = id
        self.mode = mode
        self.deadline = deadline
    }
}

public struct WorkloadRegistry: Sendable {
    public private(set) var records: [WorkloadRecord] = []

    private var tombstones: Set<String> = []

    public init() {}

    @discardableResult
    public mutating func apply(
        _ event: WorkloadEvent,
        mode: Mode,
        options: WorkloadOptions = WorkloadOptions(),
        at: ClockSample
    ) throws -> Bool {
        try options.validate()
        try Self.validate(event, at: at)

        let key = WorkloadRecord.identityKey(
            source: event.source,
            sessionID: event.sessionID,
            turnID: event.turnID,
            taskID: event.taskID
        )
        if tombstones.contains(key) {
            return false
        }

        if let index = records.firstIndex(where: { $0.id == key }) {
            let previous = records[index]
            guard event.eventID != previous.lastEventID,
                  event.sequence > previous.sequence else {
                return false
            }

            let terminalEvent = event.state == .finished || event.state == .failed
            let deadlineExpired = previous.hardDeadline.isExpired(at: at)
            let bootChanged = previous.startedAt.bootID != at.bootID
            let nextState: WorkloadState
            if terminalEvent {
                nextState = Self.terminalState(for: event)
            } else if deadlineExpired || bootChanged {
                nextState = .unknown
            } else {
                nextState = event.state
            }

            let nextHoldDeadline: SessionDeadline
            if nextState == .working, !deadlineExpired, !bootChanged {
                nextHoldDeadline = try Self.makeHoldDeadline(
                    duration: options.staleAfter,
                    at: at,
                    hardDeadline: previous.hardDeadline
                )
            } else if nextState == .waiting, previous.state != .waiting,
                      !deadlineExpired, !bootChanged {
                nextHoldDeadline = try Self.makeHoldDeadline(
                    duration: options.waitingGrace,
                    at: at,
                    hardDeadline: previous.hardDeadline
                )
            } else if nextState == .idle, previous.state != .idle,
                      !deadlineExpired, !bootChanged {
                nextHoldDeadline = try Self.makeHoldDeadline(
                    duration: options.settlingInterval,
                    at: at,
                    hardDeadline: previous.hardDeadline
                )
            } else {
                nextHoldDeadline = previous.holdDeadline
            }

            records[index] = previous.updating(
                mode: mode,
                state: nextState,
                event: event,
                at: at,
                holdDeadline: nextHoldDeadline
            )
            if terminalEvent {
                tombstones.insert(key)
            }
            return true
        }

        guard !tombstones.contains(key) else {
            return false
        }
        guard Self.knownIdentityCount(records: records, tombstones: tombstones) < 512 else {
            throw WorkloadError.identityCapacityReached
        }

        guard event.state == .working else {
            tombstones.insert(key)
            return true
        }

        let hardDeadline: SessionDeadline
        let holdDeadline: SessionDeadline
        do {
            hardDeadline = try SessionDeadline(
                duration: .seconds(options.maximumDuration),
                clock: at
            )
            holdDeadline = try Self.makeHoldDeadline(
                duration: options.staleAfter,
                at: at,
                hardDeadline: hardDeadline
            )
        } catch {
            throw WorkloadError.invalidDeadline
        }

        if records.count >= 128 {
            guard let endedIndex = records.indices
                .filter({ tombstones.contains(records[$0].id) })
                .min(by: { records[$0].updatedAt.wallDate < records[$1].updatedAt.wallDate }) else {
                throw WorkloadError.recordCapacityReached
            }
            records.remove(at: endedIndex)
        }

        records.append(WorkloadRecord(
            source: event.source,
            sessionID: event.sessionID,
            turnID: event.turnID,
            taskID: event.taskID,
            mode: mode,
            state: .working,
            lastEventID: event.eventID,
            sequence: event.sequence,
            startedAt: at,
            updatedAt: at,
            hardDeadline: hardDeadline,
            holdDeadline: holdDeadline,
            exitCode: event.exitCode
        ))
        return true
    }

    public mutating func expire(at: ClockSample) {
        guard at.isValid else {
            return
        }
        for index in records.indices {
            let record = records[index]
            guard record.state != .finished, record.state != .failed, record.state != .unknown else {
                continue
            }
            let bootChanged = record.startedAt.bootID != at.bootID
            let hardExpired = record.hardDeadline.isExpired(at: at)
            let staleWorking = record.state == .working && record.holdDeadline.isExpired(at: at)
            guard bootChanged || hardExpired || staleWorking else {
                continue
            }
            records[index] = record.replacingState(.unknown, updatedAt: at)
        }
    }

    public func activeHolds(at: ClockSample) -> [WorkloadHold] {
        guard at.isValid else {
            return []
        }
        return records.compactMap { record in
            guard record.state == .working || record.state == .waiting || record.state == .idle,
                  !record.hardDeadline.isExpired(at: at),
                  !record.holdDeadline.isExpired(at: at) else {
                return nil
            }
            return WorkloadHold(id: record.id, mode: record.mode, deadline: record.holdDeadline)
        }
    }

    public mutating func removeAll() {
        records.removeAll(keepingCapacity: false)
        tombstones.removeAll(keepingCapacity: false)
    }

    public mutating func removeAgentRequests() {
        tombstones.formUnion(records.filter { $0.source != .command }.map(\.id))
        records.removeAll { $0.source != .command }
    }

    private static func validate(_ event: WorkloadEvent, at: ClockSample) throws {
        guard at.isValid,
              WorkloadRecord.isValidOpaqueID(event.eventID, maximumBytes: 128),
              WorkloadRecord.isValidOpaqueID(event.sessionID, maximumBytes: 128),
              WorkloadRecord.isValidOpaqueID(event.turnID, maximumBytes: 128),
              event.taskID.map({ WorkloadRecord.isValidOpaqueID($0, maximumBytes: 128) }) ?? true,
              WorkloadRecord.isValidOpaqueID(event.adapterVersion, maximumBytes: 64),
              event.sequence > 0,
              event.timestamp.timeIntervalSinceReferenceDate.isFinite else {
            throw WorkloadError.invalidEvent
        }
        let age = event.timestamp.timeIntervalSince(at.wallDate)
        guard age.isFinite, age <= 5, age >= -60 else {
            throw WorkloadError.eventTimestampOutOfRange
        }
    }

    private static func terminalState(for event: WorkloadEvent) -> WorkloadState {
        switch event.state {
        case .failed:
            return .failed
        case .finished where event.source == .command:
            guard let exitCode = event.exitCode else {
                return .unknown
            }
            return exitCode == 0 ? .finished : .failed
        case .finished:
            return .finished
        case .working, .waiting, .idle, .unknown:
            return event.state
        }
    }

    private static func makeHoldDeadline(
        duration: Double,
        at: ClockSample,
        hardDeadline: SessionDeadline
    ) throws -> SessionDeadline {
        guard let remaining = hardDeadline.remaining(at: at), remaining > 0 else {
            throw WorkloadError.invalidDeadline
        }
        let boundedDuration = min(duration, remaining)
        guard boundedDuration.isFinite, boundedDuration > 0 else {
            throw WorkloadError.invalidDeadline
        }
        do {
            return try SessionDeadline(duration: .seconds(boundedDuration), clock: at)
        } catch {
            throw WorkloadError.invalidDeadline
        }
    }

    private static func knownIdentityCount(
        records: [WorkloadRecord],
        tombstones: Set<String>
    ) -> Int {
        var keys = tombstones
        keys.formUnion(records.map(\.id))
        return keys.count
    }
}

private extension WorkloadRecord {
    func replacingState(_ state: WorkloadState, updatedAt: ClockSample) -> Self {
        Self(
            source: source,
            sessionID: sessionID,
            turnID: turnID,
            taskID: taskID,
            mode: mode,
            state: state,
            lastEventID: lastEventID,
            sequence: sequence,
            startedAt: startedAt,
            updatedAt: updatedAt,
            hardDeadline: hardDeadline,
            holdDeadline: holdDeadline,
            exitCode: exitCode
        )
    }
}
