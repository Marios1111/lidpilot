import Foundation
import XCTest
@testable import LidPilotCore

class CoreTestCase: XCTestCase {
    let bootID = "boot-a"

    func clock(
        continuous: Double,
        wall: TimeInterval = 1_700_000_000,
        bootID: String? = nil
    ) -> ClockSample {
        ClockSample(
            continuousSeconds: continuous,
            wallDate: Date(timeIntervalSince1970: wall),
            bootID: bootID ?? self.bootID
        )
    }

    func snapshot(
        sampledAt: ClockSample? = nil,
        lid: LidState = .open,
        power: PowerSource = .external,
        batteryPercent: Int? = 80,
        thermal: ThermalLevel = .nominal,
        lowPowerMode: Bool? = false,
        externalDisplayCount: Int? = 1,
        sleepDisabled: FlagState = .off
    ) -> PowerSnapshot {
        PowerSnapshot(
            sampledAt: sampledAt ?? clock(continuous: 100),
            lid: lid,
            power: power,
            batteryPercent: batteryPercent,
            thermal: thermal,
            lowPowerMode: lowPowerMode,
            externalDisplayCount: externalDisplayCount,
            sleepDisabled: sleepDisabled
        )
    }
}
