import Foundation

public enum SafetyPolicyError: Error, Equatable, Sendable {
    case invalidBatteryFloor(Int)
}

public struct SafetyPolicy: Codable, Equatable, Sendable {
    public let batteryFloor: Int
    public let allowBattery: Bool
    public let respectLowPowerMode: Bool

    public init(
        batteryFloor: Int = 20,
        allowBattery: Bool = false,
        respectLowPowerMode: Bool = true
    ) {
        self.batteryFloor = batteryFloor
        self.allowBattery = allowBattery
        self.respectLowPowerMode = respectLowPowerMode
    }

    public func validate() throws {
        guard [10, 20, 30].contains(batteryFloor) else {
            throw SafetyPolicyError.invalidBatteryFloor(batteryFloor)
        }
    }

    public func evaluate(
        snapshot: PowerSnapshot,
        mode: Mode,
        clock: ClockSample,
        requireOpenLid: Bool = false
    ) -> SafetyReason? {
        guard [10, 20, 30].contains(batteryFloor) else {
            return .unavailable
        }
        guard snapshot.sampledAt.isValid, clock.isValid,
              snapshot.sampledAt.bootID == clock.bootID else {
            return .unavailable
        }

        let age = clock.continuousSeconds - snapshot.sampledAt.continuousSeconds
        let wallIsFuture = snapshot.sampledAt.wallDate > clock.wallDate
        guard age >= 0, age <= 30, !wallIsFuture else {
            return .unavailable
        }

        guard snapshot.power != .unknown, snapshot.thermal != .unknown else {
            return .unavailable
        }

        switch snapshot.thermal {
        case .serious, .critical:
            return .thermal
        case .nominal, .fair, .unknown:
            break
        }

        if snapshot.power == .battery {
            guard let battery = snapshot.batteryPercent, (0...100).contains(battery) else {
                return .unavailable
            }
            if battery <= batteryFloor {
                return .battery
            }
        } else if let battery = snapshot.batteryPercent, !(0...100).contains(battery) {
            return .unavailable
        }

        if requireOpenLid, snapshot.lid != .open {
            return .lidUnknown
        }

        guard mode == .smart || mode == .closed else {
            return nil
        }

        guard snapshot.lid != .unknown,
              snapshot.lowPowerMode != nil,
              snapshot.externalDisplayCount.map({ $0 >= 0 }) == true else {
            if snapshot.lid == .unknown {
                return .lidUnknown
            }
            return .unavailable
        }

        if snapshot.power == .battery {
            if !allowBattery {
                return .unplugged
            }
            if respectLowPowerMode, snapshot.lowPowerMode == true {
                return .lowPower
            }
        }

        return nil
    }
}
