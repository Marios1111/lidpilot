import IOKit.pwr_mgt
import Testing
@testable import LidPilotRuntime

struct PowerAssertionsTests {
    @Test func expiredAssertionIDCanBeClearedWhenReadbackConfirmsItIsGone() {
        #expect(AssertionRemovalOutcome.evaluate(
            releaseResult: kIOReturnBadArgument,
            assertionPresent: false
        ) == .clearID)
    }

    @Test func releaseStillFailsClosedForAnActiveAssertionOrUnexpectedError() {
        #expect(AssertionRemovalOutcome.evaluate(
            releaseResult: kIOReturnBadArgument,
            assertionPresent: true
        ) == .assertionStillPresent)
        #expect(AssertionRemovalOutcome.evaluate(
            releaseResult: kIOReturnError,
            assertionPresent: false
        ) == .releaseFailed)
    }

    @Test func successfulOrAlreadyMissingReleaseStillRequiresAbsentReadback() {
        #expect(AssertionRemovalOutcome.evaluate(
            releaseResult: kIOReturnSuccess,
            assertionPresent: false
        ) == .clearID)
        #expect(AssertionRemovalOutcome.evaluate(
            releaseResult: kIOReturnNotFound,
            assertionPresent: false
        ) == .clearID)
        #expect(AssertionRemovalOutcome.evaluate(
            releaseResult: kIOReturnSuccess,
            assertionPresent: true
        ) == .assertionStillPresent)
    }
}
