import Foundation

public enum Mode: String, Codable, CaseIterable, Sendable {
    case smart
    case display
    case closed

    public var title: String {
        switch self {
        case .smart:
            return "Follow Lid"
        case .display:
            return "Keep Screen On"
        case .closed:
            return "Keep Mac Running"
        }
    }

    public var needsHelper: Bool {
        switch self {
        case .smart, .closed:
            return true
        case .display:
            return false
        }
    }
}

public enum LidState: String, Codable, Sendable {
    case open
    case closed
    case unknown
}

public enum PowerSource: String, Codable, Sendable {
    case external
    case battery
    case unknown
}

public enum ThermalLevel: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown
}

public enum FlagState: String, Codable, Sendable {
    case on
    case off
    case unknown
}

public struct ClockSample: Codable, Sendable, Equatable {
    public let continuousSeconds: Double
    public let wallDate: Date
    public let bootID: String

    public init(continuousSeconds: Double, wallDate: Date, bootID: String) {
        self.continuousSeconds = continuousSeconds
        self.wallDate = wallDate
        self.bootID = bootID
    }

    var isValid: Bool {
        continuousSeconds.isFinite &&
            wallDate.timeIntervalSinceReferenceDate.isFinite &&
            !bootID.isEmpty
    }
}

public enum SessionDuration: Codable, Equatable, Sendable {
    case seconds(Double)
    case until(Date)
    case indefinite
}

public struct PowerSnapshot: Codable, Equatable, Sendable {
    public let sampledAt: ClockSample
    public let lid: LidState
    public let power: PowerSource
    public let batteryPercent: Int?
    public let thermal: ThermalLevel
    public let lowPowerMode: Bool?
    public let externalDisplayCount: Int?
    public let sleepDisabled: FlagState

    public init(
        sampledAt: ClockSample,
        lid: LidState = .unknown,
        power: PowerSource = .unknown,
        batteryPercent: Int? = nil,
        thermal: ThermalLevel = .unknown,
        lowPowerMode: Bool? = nil,
        externalDisplayCount: Int? = nil,
        sleepDisabled: FlagState = .unknown
    ) {
        self.sampledAt = sampledAt
        self.lid = lid
        self.power = power
        self.batteryPercent = batteryPercent
        self.thermal = thermal
        self.lowPowerMode = lowPowerMode
        self.externalDisplayCount = externalDisplayCount
        self.sleepDisabled = sleepDisabled
    }
}

public enum SafetyReason: String, Codable, Sendable {
    case thermal
    case battery
    case unplugged
    case lowPower
    case unavailable
    case lidUnknown
    case deadline
    case externalChange
    case helperUnavailable
}
