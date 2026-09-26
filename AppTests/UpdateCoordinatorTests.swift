import Foundation
import ServiceManagement
import Sparkle
import XCTest
import LidPilotCore
import LidPilotRuntime

@MainActor final class UpdateCoordinatorTests: XCTestCase {
    func testCurrentBuildInterruptionHoldsBarrierSynchronouslyAndWaitsForUser() async throws {
        let fixture = try makeFixture(build: "100", pendingBuild: "100", restoreHelper: true)
        defer { fixture.cleanupDefaults() }

        XCTAssertTrue(fixture.model.controller.updateBarrier)
        XCTAssertFalse(fixture.model.controller.canStart)

        await fixture.coordinator.reconcilePreviousUpdateForTesting()

        XCTAssertEqual(fixture.defaults.string(forKey: "updatePendingBuild"), "100")
        XCTAssertTrue(fixture.defaults.bool(forKey: "updateRestoreHelper"))
        XCTAssertTrue(fixture.model.controller.updateBarrier)
        XCTAssertEqual(fixture.helper.registerCount, 0)
        XCTAssertEqual(fixture.updater.checkCount, 0)
    }

    func testOlderBuildRestoresHelperAndClearsPersistedMarkers() async throws {
        let fixture = try makeFixture(build: "100", pendingBuild: "99", restoreHelper: true,
                                     helperStatus: .notRegistered, registrationResult: .enabled)
        defer { fixture.cleanupDefaults() }
        XCTAssertTrue(fixture.model.controller.updateBarrier)

        await fixture.coordinator.reconcilePreviousUpdateForTesting()

        XCTAssertEqual(fixture.helper.registerCount, 1)
        XCTAssertTrue(fixture.helper.enabled)
        XCTAssertNil(fixture.defaults.object(forKey: "updatePendingBuild"))
        XCTAssertNil(fixture.defaults.object(forKey: "updateRestoreHelper"))
        XCTAssertFalse(fixture.model.controller.updateBarrier)
        XCTAssertEqual(fixture.model.controller.phase, .off)
    }

    func testOlderBuildKeepsRepairHintWhenHelperNeedsApproval() async throws {
        let fixture = try makeFixture(build: "100", pendingBuild: "99", restoreHelper: true,
                                     helperStatus: .notRegistered, registrationResult: .requiresApproval)
        defer { fixture.cleanupDefaults() }

        await fixture.coordinator.reconcilePreviousUpdateForTesting()

        XCTAssertEqual(fixture.helper.registerCount, 1)
        XCTAssertFalse(fixture.helper.enabled)
        XCTAssertNil(fixture.defaults.object(forKey: "updatePendingBuild"))
        XCTAssertTrue(fixture.defaults.bool(forKey: "updateRestoreHelper"))
        XCTAssertFalse(fixture.model.controller.updateBarrier)
        XCTAssertTrue(fixture.coordinator.status.localizedCaseInsensitiveContains("approve or repair"))
    }

    func testUnregisterFailureVetoesUpdateAndRunsCleanup() async throws {
        let fixture = try makeFixture(build: "100", helperStatus: .enabled,
                                     unregisterError: UpdateTestFailure.unregister)
        defer { fixture.cleanupDefaults() }

        fixture.coordinator.check()
        let cleanupFinished = await waitUntil {
            fixture.helper.unregisterCount == 1 && !fixture.model.controller.updateBarrier &&
                fixture.coordinator.status.contains("scripted unregister failure")
        }
        XCTAssertTrue(cleanupFinished)

        XCTAssertEqual(fixture.updater.checkCount, 0)
        XCTAssertEqual(fixture.helper.registerCount, 1)
        XCTAssertTrue(fixture.helper.enabled)
        XCTAssertNil(fixture.defaults.object(forKey: "updatePendingBuild"))
        XCTAssertNil(fixture.defaults.object(forKey: "updateRestoreHelper"))
        XCTAssertFalse(fixture.model.controller.updateBarrier)
        XCTAssertTrue(fixture.coordinator.status.contains("scripted unregister failure"))
        XCTAssertEqual(fixture.model.transport.sendCount, 0)
    }

    func testNetworkFailureAndDuplicateFinishCallbacksRestoreExactlyOnce() async throws {
        let fixture = try makeFixture(build: "100", helperStatus: .enabled)
        defer { fixture.cleanupDefaults() }
        fixture.coordinator.check()
        let updateCheckStarted = await waitUntil { fixture.updater.checkCount == 1 }
        XCTAssertTrue(updateCheckStarted)
        XCTAssertTrue(fixture.model.controller.updateBarrier)
        XCTAssertEqual(fixture.defaults.string(forKey: "updatePendingBuild"), "100")
        XCTAssertTrue(fixture.defaults.bool(forKey: "updateRestoreHelper"))
        XCTAssertEqual(fixture.helper.status, .notRegistered)

        let networkError = URLError(.notConnectedToInternet)
        fixture.coordinator.finishUpdateCycleForTesting(error: networkError)
        fixture.coordinator.finishUpdateCycleForTesting(error: networkError)
        await fixture.coordinator.waitForUpdateCycleCleanupForTesting()

        XCTAssertEqual(fixture.helper.registerCount, 1)
        XCTAssertTrue(fixture.helper.enabled)
        XCTAssertNil(fixture.defaults.object(forKey: "updatePendingBuild"))
        XCTAssertNil(fixture.defaults.object(forKey: "updateRestoreHelper"))
        XCTAssertFalse(fixture.model.controller.updateBarrier)
        XCTAssertEqual(fixture.model.controller.phase, .off)
        XCTAssertEqual(fixture.model.offEventCount, 1)
        XCTAssertEqual(fixture.coordinator.status, networkError.localizedDescription)
        XCTAssertEqual(fixture.model.transport.sendCount, 0)
    }

    func testCommittedInstallRetainsBarrierAndSameBuildRelaunchKeepsIt() async throws {
        let first = try makeFixture(build: "100", helperStatus: .enabled)
        defer { first.cleanupDefaults() }
        first.coordinator.check()
        let updateCheckStarted = await waitUntil { first.updater.checkCount == 1 }
        XCTAssertTrue(updateCheckStarted)
        XCTAssertTrue(first.model.controller.updateBarrier)

        first.coordinator.commitInstallationForTesting()
        first.coordinator.finishUpdateCycleForTesting(error: nil)
        await first.coordinator.waitForUpdateCycleCleanupForTesting()

        XCTAssertTrue(first.model.controller.updateBarrier)
        XCTAssertEqual(first.defaults.string(forKey: "updatePendingBuild"), "100")
        XCTAssertTrue(first.defaults.bool(forKey: "updateRestoreHelper"))
        XCTAssertEqual(first.helper.registerCount, 0)
        XCTAssertFalse(first.model.controller.canStart)

        let relaunchedModel = makeModel()
        let relaunchedUpdater = TestUpdater()
        let relaunched = UpdateCoordinator(testing: relaunchedModel, defaults: first.defaults, build: "100",
                                           updater: relaunchedUpdater, lidIsOpen: { true })
        XCTAssertTrue(relaunchedModel.controller.updateBarrier)
        await relaunched.reconcilePreviousUpdateForTesting()

        XCTAssertTrue(relaunchedModel.controller.updateBarrier)
        XCTAssertEqual(first.defaults.string(forKey: "updatePendingBuild"), "100")
        XCTAssertEqual(relaunchedUpdater.checkCount, 0)
        XCTAssertFalse(relaunchedModel.controller.canStart)
    }

    func testAutomaticCheckIsRejectedWithoutDisturbingActiveDisplaySession() async throws {
        let fixture = try makeFixture(build: "100")
        defer { fixture.cleanupDefaults() }
        await fixture.model.controller.start(mode: .display, duration: .seconds(600), policy: SafetyPolicy())
        XCTAssertEqual(fixture.model.controller.phase, .active)
        XCTAssertTrue(fixture.model.controller.hasSession)
        XCTAssertEqual(fixture.model.controller.assertions.display, .on)

        do {
            try fixture.coordinator.authorizeUpdateCheckForTesting(.updatesInBackground)
            XCTFail("Expected an automatic background update check to be deferred during an active session.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Turn LidPilot Off"))
        }
        fixture.coordinator.check()

        XCTAssertEqual(fixture.coordinator.status, "Turn LidPilot Off before checking for updates.")
        XCTAssertEqual(fixture.updater.checkCount, 0)
        XCTAssertEqual(fixture.helper.unregisterCount, 0)
        XCTAssertEqual(fixture.model.controller.phase, .active)
        XCTAssertEqual(fixture.model.controller.assertions.display, .on)
        XCTAssertFalse(fixture.model.controller.updateBarrier)
        XCTAssertNil(fixture.defaults.object(forKey: "updatePendingBuild"))
        XCTAssertEqual(fixture.model.transport.sendCount, 0)

        await fixture.model.controller.stop()
    }

    private func makeFixture(build: String, pendingBuild: String? = nil, restoreHelper: Bool = false,
                             helperStatus: SMAppService.Status = .notRegistered,
                             registrationResult: SMAppService.Status = .enabled,
                             unregisterError: (any Error)? = nil) throws -> Fixture {
        let suite = "com.lidpilot.UpdateCoordinatorTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw UpdateTestFailure.defaultsUnavailable
        }
        defaults.removePersistentDomain(forName: suite)
        if let pendingBuild { defaults.set(pendingBuild, forKey: "updatePendingBuild") }
        if restoreHelper { defaults.set(true, forKey: "updateRestoreHelper") }

        let helper = TestUpdateHelper(status: helperStatus, registrationResult: registrationResult,
                                     unregisterError: unregisterError)
        let model = makeModel(helper: helper)
        let updater = TestUpdater()
        let coordinator = UpdateCoordinator(testing: model, defaults: defaults, build: build,
                                            updater: updater, lidIsOpen: { true })
        return Fixture(suite: suite, defaults: defaults, model: model, helper: helper,
                       updater: updater, coordinator: coordinator)
    }

    private func makeModel(helper: TestUpdateHelper = TestUpdateHelper()) -> TestUpdateModel {
        let stamp = ClockSample(continuousSeconds: 10, wallDate: Date(timeIntervalSince1970: 1_700_000_000), bootID: "test-boot")
        let sample = PowerSnapshot(sampledAt: stamp, lid: .open, power: .external, thermal: .nominal,
                                   lowPowerMode: false, externalDisplayCount: 0, sleepDisabled: .off)
        let transport = TestUpdateTransport()
        let controller = SessionController(clock: FixedUpdateClock(sample: stamp),
                                           sampler: FixedUpdateSampler(sample: sample),
                                           power: TestUpdateAssertions(), helper: transport)
        return TestUpdateModel(controller: controller, helper: helper, transport: transport)
    }

    private func waitUntil(_ predicate: @MainActor () -> Bool, attempts: Int = 200) async -> Bool {
        for _ in 0..<attempts {
            if predicate() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return predicate()
    }
}

@MainActor private struct Fixture {
    let suite: String
    let defaults: UserDefaults
    let model: TestUpdateModel
    let helper: TestUpdateHelper
    let updater: TestUpdater
    let coordinator: UpdateCoordinator

    func cleanupDefaults() {
        defaults.removePersistentDomain(forName: suite)
    }
}

@MainActor private final class TestUpdateModel: UpdateCoordinatorModel {
    let controller: SessionController
    let helper: TestUpdateHelper
    let transport: TestUpdateTransport
    var onboardingComplete = true
    private(set) var offEventCount = 0

    var updateHelper: any UpdateCoordinatorHelper { helper }

    init(controller: SessionController, helper: TestUpdateHelper, transport: TestUpdateTransport) {
        self.controller = controller
        self.helper = helper
        self.transport = transport
        controller.onEvent = { [weak self] phase, _ in
            if phase == .off { self?.offEventCount += 1 }
        }
    }

    func refreshHelper() {
        // Closed-lid helper support stays disabled in these open-lid, in-memory tests.
    }
}

@MainActor private final class TestUpdateHelper: UpdateCoordinatorHelper {
    let signed = true
    private(set) var status: SMAppService.Status
    let registrationResult: SMAppService.Status
    let unregisterError: (any Error)?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    var enabled: Bool { status == .enabled }

    init(status: SMAppService.Status = .notRegistered,
         registrationResult: SMAppService.Status = .enabled,
         unregisterError: (any Error)? = nil) {
        self.status = status
        self.registrationResult = registrationResult
        self.unregisterError = unregisterError
    }

    func register() {
        registerCount += 1
        status = registrationResult
    }

    func unregister() async throws {
        unregisterCount += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}

@MainActor private final class TestUpdater: UpdateCoordinatorTestUpdater {
    var canCheckForUpdates = true
    var automaticallyChecksForUpdates = true
    private(set) var checkCount = 0

    func checkForUpdates() { checkCount += 1 }
}

private struct FixedUpdateClock: RuntimeClock {
    let sample: ClockSample
    func now() -> ClockSample { sample }
}

private struct FixedUpdateSampler: PowerSampling {
    let sample: PowerSnapshot
    func sample(flag: FlagState) -> PowerSnapshot {
        PowerSnapshot(sampledAt: sample.sampledAt, lid: sample.lid, power: sample.power,
                      batteryPercent: sample.batteryPercent, thermal: sample.thermal,
                      lowPowerMode: sample.lowPowerMode, externalDisplayCount: sample.externalDisplayCount,
                      sleepDisabled: flag)
    }
}

@MainActor private final class TestUpdateAssertions: PowerAssertions {
    private(set) var state = AssertionState.off
    func apply(system: Bool, display: Bool, timeout: Double) throws -> AssertionState {
        state = AssertionState(system: system ? .on : .off, display: display ? .on : .off)
        return state
    }
    func release() throws -> AssertionState {
        state = .off
        return state
    }
    func observed() -> AssertionState { state }
    func sleep() throws { XCTFail("Update tests must never request system sleep.") }
}

@MainActor private final class TestUpdateTransport: HelperTransport {
    private(set) var sendCount = 0
    func send(_ request: WireRequest) async throws -> WireReply {
        sendCount += 1
        throw RuntimeFailure.unavailable("The updater harness must not contact a helper.")
    }
    func disconnect() {}
}

private enum UpdateTestFailure: LocalizedError {
    case defaultsUnavailable
    case unregister

    var errorDescription: String? {
        switch self {
        case .defaultsUnavailable: "Could not create an isolated defaults suite."
        case .unregister: "scripted unregister failure"
        }
    }
}
