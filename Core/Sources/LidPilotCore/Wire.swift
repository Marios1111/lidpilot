import Foundation

public enum WireOperation: String, Codable, CaseIterable, Sendable {
    case inspect
    case acquire
    case renew
    case replace
    case release
    case recover
}

public enum WireValidationError: Error, Equatable, Sendable {
    case unsupportedProtocol(Int)
    case generationRequired
    case payloadRequired(WireOperation)
    case payloadForbidden(WireOperation)
    case displayAcquire
    case invalidPolicy
    case invalidDeadline
}

public enum WireCodecError: Error, Equatable, Sendable {
    case oversized
    case malformed
}

public struct WireRequest: Codable, Equatable, Sendable {
    public static let protocolVersion = 2
    public static let maximumEncodedSize = 16 * 1024

    public var protocolVersion: Int
    public var operation: WireOperation
    public var sessionID: UUID
    public var generation: UInt64
    public var deadline: SessionDeadline?
    public var policy: SafetyPolicy?
    public var mode: Mode?

    public init(
        protocolVersion: Int = WireRequest.protocolVersion,
        operation: WireOperation,
        sessionID: UUID,
        generation: UInt64,
        deadline: SessionDeadline? = nil,
        policy: SafetyPolicy? = nil,
        mode: Mode? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.operation = operation
        self.sessionID = sessionID
        self.generation = generation
        self.deadline = deadline
        self.policy = policy
        self.mode = mode
    }

    public func validate() throws {
        guard protocolVersion == Self.protocolVersion else {
            throw WireValidationError.unsupportedProtocol(protocolVersion)
        }
        guard generation > 0 else {
            throw WireValidationError.generationRequired
        }

        switch operation {
        case .acquire, .replace:
            guard let deadline, let policy, let mode else {
                throw WireValidationError.payloadRequired(operation)
            }
            guard mode != .display else {
                throw WireValidationError.displayAcquire
            }
            do {
                try deadline.validate()
            } catch {
                throw WireValidationError.invalidDeadline
            }
            do {
                try policy.validate()
            } catch {
                throw WireValidationError.invalidPolicy
            }
        case .renew:
            guard let deadline else {
                throw WireValidationError.payloadRequired(operation)
            }
            if mode == .display {
                throw WireValidationError.displayAcquire
            }
            do {
                try deadline.validate()
            } catch {
                throw WireValidationError.invalidDeadline
            }
            if let policy {
                do {
                    try policy.validate()
                } catch {
                    throw WireValidationError.invalidPolicy
                }
            }
        case .inspect, .release, .recover:
            guard deadline == nil, policy == nil, mode == nil else {
                throw WireValidationError.payloadForbidden(operation)
            }
        }
    }

    public static func encode(_ request: WireRequest) throws -> Data {
        try request.validate()
        let data: Data
        do {
            data = try JSONEncoder().encode(request)
        } catch let error as WireValidationError {
            throw error
        } catch {
            throw WireCodecError.malformed
        }
        guard data.count <= maximumEncodedSize else {
            throw WireCodecError.oversized
        }
        return data
    }

    public static func decode(_ data: Data) throws -> WireRequest {
        guard data.count <= maximumEncodedSize else {
            throw WireCodecError.oversized
        }
        do {
            return try JSONDecoder().decode(Self.self, from: data)
        } catch let error as WireValidationError {
            throw error
        } catch {
            throw WireCodecError.malformed
        }
    }

    public func encoded() throws -> Data {
        try Self.encode(self)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.protocolVersion = try container.decode(Int.self, forKey: .protocolVersion)
        self.operation = try container.decode(WireOperation.self, forKey: .operation)
        self.sessionID = try container.decode(UUID.self, forKey: .sessionID)
        self.generation = try container.decode(UInt64.self, forKey: .generation)
        self.deadline = try container.decodeIfPresent(SessionDeadline.self, forKey: .deadline)
        self.policy = try container.decodeIfPresent(SafetyPolicy.self, forKey: .policy)
        self.mode = try container.decodeIfPresent(Mode.self, forKey: .mode)
        try validate()
    }

    private enum CodingKeys: String, CodingKey {
        case protocolVersion
        case operation
        case sessionID
        case generation
        case deadline
        case policy
        case mode
    }
}

public enum WireFailureCode: String, Codable, Sendable {
    case busy, invalidRequest, unauthorized, operationFailed, recoveryRequired, unavailable
}

public struct HelperHealth: Codable, Equatable, Sendable {
    public var journalHealthy: Bool
    public var powerStateReadable: Bool
    public var watchdogAvailable: Bool
    public init(journalHealthy: Bool, powerStateReadable: Bool, watchdogAvailable: Bool) {
        self.journalHealthy = journalHealthy
        self.powerStateReadable = powerStateReadable
        self.watchdogAvailable = watchdogAvailable
    }
}

public struct WireReply: Codable, Equatable, Sendable {
    public static let protocolVersion = WireRequest.protocolVersion
    public static let maximumEncodedSize = 16 * 1024

    public var protocolVersion: Int
    public var helperBuild: String
    public var flag: FlagState
    public var ownsOverride: Bool
    public var recoveryPending: Bool
    public var leaseActive: Bool
    public var message: String
    public var success: Bool
    public var sample: PowerSnapshot?
    public var failureCode: WireFailureCode?
    public var health: HelperHealth?

    public init(
        protocolVersion: Int = WireReply.protocolVersion,
        helperBuild: String,
        flag: FlagState = .unknown,
        ownsOverride: Bool = false,
        recoveryPending: Bool = false,
        leaseActive: Bool = false,
        message: String = "",
        success: Bool = false,
        sample: PowerSnapshot? = nil,
        failureCode: WireFailureCode? = nil,
        health: HelperHealth? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.helperBuild = helperBuild
        self.flag = flag
        self.ownsOverride = ownsOverride
        self.recoveryPending = recoveryPending
        self.leaseActive = leaseActive
        self.message = message
        self.success = success
        self.sample = sample
        self.failureCode = failureCode
        self.health = health
    }

    public func validate() throws {
        guard protocolVersion == Self.protocolVersion else {
            throw WireValidationError.unsupportedProtocol(protocolVersion)
        }
    }

    public static func encode(_ reply: WireReply) throws -> Data {
        try reply.validate()
        let data: Data
        do {
            data = try JSONEncoder().encode(reply)
        } catch {
            throw WireCodecError.malformed
        }
        guard data.count <= maximumEncodedSize else {
            throw WireCodecError.oversized
        }
        return data
    }

    public static func decode(_ data: Data) throws -> WireReply {
        guard data.count <= maximumEncodedSize else {
            throw WireCodecError.oversized
        }
        do {
            return try JSONDecoder().decode(Self.self, from: data)
        } catch let error as WireValidationError {
            throw error
        } catch {
            throw WireCodecError.malformed
        }
    }

    public func encoded() throws -> Data {
        try Self.encode(self)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.protocolVersion = try container.decode(Int.self, forKey: .protocolVersion)
        self.helperBuild = try container.decode(String.self, forKey: .helperBuild)
        self.flag = try container.decode(FlagState.self, forKey: .flag)
        self.ownsOverride = try container.decode(Bool.self, forKey: .ownsOverride)
        self.recoveryPending = try container.decode(Bool.self, forKey: .recoveryPending)
        self.leaseActive = try container.decode(Bool.self, forKey: .leaseActive)
        self.message = try container.decode(String.self, forKey: .message)
        self.success = try container.decode(Bool.self, forKey: .success)
        self.sample = try container.decodeIfPresent(PowerSnapshot.self, forKey: .sample)
        self.failureCode = try container.decodeIfPresent(WireFailureCode.self, forKey: .failureCode)
        self.health = try container.decodeIfPresent(HelperHealth.self, forKey: .health)
        try validate()
    }

    private enum CodingKeys: String, CodingKey {
        case protocolVersion
        case helperBuild
        case flag
        case ownsOverride
        case recoveryPending
        case leaseActive
        case message
        case success
        case sample
        case failureCode
        case health
    }
}
