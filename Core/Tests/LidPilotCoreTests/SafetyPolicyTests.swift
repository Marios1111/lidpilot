import Foundation
import XCTest
@testable import LidPilotCore

final class SafetyPolicyTests: CoreTestCase {
    func testSafetyPolicyValidatesBatteryFloorWithoutClamping() {
        let invalid = SafetyPolicy(batteryFloor: 15)
        XCTAssertThrowsError(try invalid.validate())
        XCTAssertEqual(invalid.batteryFloor, 15)
        XCTAssertNoThrow(try SafetyPolicy().validate())
    }

    func testSeriousThermalPressureWinsOverBatteryReasonForEveryMode() throws {
        let policy = SafetyPolicy()
        let sample = snapshot(power: .battery, batteryPercent: 10, thermal: .serious)
        for mode in Mode.allCases {
            XCTAssertEqual(
                policy.evaluate(snapshot: sample, mode: mode, clock: clock(continuous: 100)),
                .thermal,
                mode.rawValue
            )
        }
    }

    func testBatteryFloorIsInclusiveAndAppliesToDisplay() throws {
        let policy = SafetyPolicy(batteryFloor: 20, allowBattery: true)
        let atFloor = snapshot(power: .battery, batteryPercent: 20)
        let aboveFloor = snapshot(power: .battery, batteryPercent: 21)

        XCTAssertEqual(policy.evaluate(snapshot: atFloor, mode: .display, clock: clock(continuous: 100)), .battery)
        XCTAssertNil(policy.evaluate(snapshot: aboveFloor, mode: .display, clock: clock(continuous: 100)))
    }

    func testSmartAndClosedPauseOnBatteryUnlessExplicitlyAllowed() throws {
        let battery = snapshot(power: .battery, batteryPercent: 50)
        let paused = SafetyPolicy(allowBattery: false)
        let allowed = SafetyPolicy(allowBattery: true)

        XCTAssertEqual(paused.evaluate(snapshot: battery, mode: .smart, clock: clock(continuous: 100)), .unplugged)
        XCTAssertEqual(paused.evaluate(snapshot: battery, mode: .closed, clock: clock(continuous: 100)), .unplugged)
        XCTAssertNil(allowed.evaluate(snapshot: battery, mode: .smart, clock: clock(continuous: 100)))
        XCTAssertNil(allowed.evaluate(snapshot: battery, mode: .closed, clock: clock(continuous: 100)))
    }

    func testLowPowerModePausesOnlySmartAndClosedOnBattery() throws {
        let battery = snapshot(power: .battery, batteryPercent: 50, lowPowerMode: true)
        let policy = SafetyPolicy(allowBattery: true, respectLowPowerMode: true)

        XCTAssertEqual(policy.evaluate(snapshot: battery, mode: .smart, clock: clock(continuous: 100)), .lowPower)
        XCTAssertEqual(policy.evaluate(snapshot: battery, mode: .closed, clock: clock(continuous: 100)), .lowPower)
        XCTAssertNil(policy.evaluate(snapshot: battery, mode: .display, clock: clock(continuous: 100)))
    }

    func testUnknownCriticalReadingsAndFreshnessBlockAllModes() throws {
        let policy = SafetyPolicy()
        let now = clock(continuous: 100)

        XCTAssertEqual(
            policy.evaluate(snapshot: snapshot(power: .unknown), mode: .display, clock: now),
            .unavailable
        )
        XCTAssertEqual(
            policy.evaluate(snapshot: snapshot(thermal: .unknown), mode: .display, clock: now),
            .unavailable
        )
        XCTAssertEqual(
            policy.evaluate(
                snapshot: snapshot(sampledAt: clock(continuous: 69)),
                mode: .display,
                clock: now
            ),
            .unavailable
        )
        XCTAssertEqual(
            policy.evaluate(
                snapshot: snapshot(sampledAt: clock(continuous: 101)),
                mode: .display,
                clock: now
            ),
            .unavailable
        )
        XCTAssertEqual(
            policy.evaluate(
                snapshot: snapshot(sampledAt: clock(continuous: 90, bootID: "boot-b")),
                mode: .display,
                clock: now
            ),
            .unavailable
        )
    }

    func testSmartAndClosedRequireKnownLidBatteryLowPowerAndTopology() throws {
        let policy = SafetyPolicy(allowBattery: true)
        let now = clock(continuous: 100)

        XCTAssertEqual(
            policy.evaluate(snapshot: snapshot(power: .battery, batteryPercent: nil), mode: .smart, clock: now),
            .unavailable
        )
        XCTAssertEqual(
            policy.evaluate(snapshot: snapshot(lowPowerMode: nil), mode: .smart, clock: now),
            .unavailable
        )
        XCTAssertEqual(
            policy.evaluate(snapshot: snapshot(lid: .unknown), mode: .closed, clock: now),
            .lidUnknown
        )
        XCTAssertEqual(
            policy.evaluate(snapshot: snapshot(externalDisplayCount: nil), mode: .closed, clock: now),
            .unavailable
        )
    }

    func testArmingWithRequireOpenLidRejectsClosedLid() throws {
        let sample = snapshot(lid: .closed)
        XCTAssertEqual(
            SafetyPolicy().evaluate(
                snapshot: sample,
                mode: .display,
                clock: clock(continuous: 100),
                requireOpenLid: true
            ),
            .lidUnknown
        )
    }
}
