import Foundation
import XCTest
@testable import LidPilotCore

final class SessionDeadlineTests: CoreTestCase {
    func testModesExposeStableWireValuesAndUserTitles() {
        XCTAssertEqual(Mode.allCases.map(\.rawValue), ["smart", "display", "closed"])
        XCTAssertEqual(Mode.smart.title, "Follow Lid")
        XCTAssertEqual(Mode.display.title, "Keep Screen On")
        XCTAssertEqual(Mode.closed.title, "Keep Mac Running")
        XCTAssertTrue(Mode.smart.needsHelper)
        XCTAssertFalse(Mode.display.needsHelper)
        XCTAssertTrue(Mode.closed.needsHelper)
    }

    func testFiniteDeadlineUsesContinuousTimeWhenWallClockChanges() throws {
        let deadline = try SessionDeadline(
            duration: .seconds(60),
            clock: clock(continuous: 100, wall: 1_700_000_000)
        )

        let afterWallAdjustment = clock(continuous: 120, wall: 1_600_000_000)
        XCTAssertFalse(deadline.isExpired(at: afterWallAdjustment))
        XCTAssertEqual(deadline.remaining(at: afterWallAdjustment)!, 40, accuracy: 0.0001)
    }

    func testFiniteDeadlineIncludesSleepAndExpiresOnContinuousDeadline() throws {
        let deadline = try SessionDeadline(
            duration: .seconds(60),
            clock: clock(continuous: 100)
        )

        XCTAssertFalse(deadline.isExpired(at: clock(continuous: 159)))
        XCTAssertTrue(deadline.isExpired(at: clock(continuous: 160)))
        XCTAssertEqual(deadline.remaining(at: clock(continuous: 170))!, 0, accuracy: 0.0001)
    }

    func testFiniteDeadlineExpiresConservativelyAfterBootChange() throws {
        let deadline = try SessionDeadline(
            duration: .seconds(60),
            clock: clock(continuous: 100, bootID: "boot-a")
        )

        let rebooted = clock(continuous: 110, bootID: "boot-b")
        XCTAssertTrue(deadline.isExpired(at: rebooted))
        XCTAssertEqual(deadline.remaining(at: rebooted)!, 0, accuracy: 0.0001)
    }

    func testUntilDeadlineUsesAbsoluteWallDateAndExpiresConservativelyAfterBootChange() throws {
        let absolute = Date(timeIntervalSince1970: 1_700_000_060)
        let deadline = try SessionDeadline(
            duration: .until(absolute),
            clock: clock(continuous: 100, wall: 1_700_000_000, bootID: "boot-a")
        )

        let beforeEnd = clock(continuous: 110, wall: 1_700_000_030, bootID: "boot-a")
        XCTAssertFalse(deadline.isExpired(at: beforeEnd))
        XCTAssertEqual(deadline.remaining(at: beforeEnd)!, 30, accuracy: 0.0001)
        let afterRebootBeforeEnd = clock(continuous: 10, wall: 1_700_000_030, bootID: "boot-b")
        XCTAssertTrue(deadline.isExpired(at: afterRebootBeforeEnd))
        XCTAssertEqual(deadline.remaining(at: afterRebootBeforeEnd)!, 0, accuracy: 0.0001)
    }

    func testIndefiniteDeadlineHasNoRemainingTimeAndDoesNotExpire() throws {
        let deadline = try SessionDeadline(duration: .indefinite, clock: clock(continuous: 100))
        XCTAssertFalse(deadline.isExpired(at: clock(continuous: 10_000, bootID: "boot-b")))
        XCTAssertNil(deadline.remaining(at: clock(continuous: 10_000, bootID: "boot-b")))
    }

    func testInvalidFiniteDurationsAreRejected() {
        for duration in [SessionDuration.seconds(0), .seconds(-1), .seconds(.nan), .seconds(.infinity)] {
            XCTAssertThrowsError(try SessionDeadline(duration: duration, clock: clock(continuous: 100)))
        }

        XCTAssertThrowsError(
            try SessionDeadline(
                duration: .until(Date(timeIntervalSinceReferenceDate: .infinity)),
                clock: clock(continuous: 100)
            )
        )
        XCTAssertThrowsError(
            try SessionDeadline(
                duration: .until(Date(timeIntervalSince1970: 1_700_000_000)),
                clock: clock(continuous: 100, wall: 1_700_000_000)
            )
        )
    }
}
