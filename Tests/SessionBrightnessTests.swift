import Testing
import LidPilotCore
@testable import LidPilotRuntime

@MainActor private final class SessionBrightness: DisplayBrightnessControlling {
    var dimmed = false
    var failDim = false
    var failRestore = false
    func setDimmed(_ value: Bool) throws {
        if value ? failDim : failRestore {
            throw RuntimeFailure.unavailable("Brightness could not be verified.")
        }
        dimmed = value
    }
}

@MainActor struct SessionBrightnessTests {
    private func setup() -> (SessionController, TestPlatform, TestAssertions, TestTransport, SessionBrightness) {
        let platform = TestPlatform()
        let power = TestAssertions()
        let transport = TestTransport(platform)
        let brightness = SessionBrightness()
        let controller = SessionController(clock: platform, sampler: platform, power: power,
                                           helper: transport, brightness: brightness)
        controller.helperAvailable = true
        return (controller, platform, power, transport, brightness)
    }

    @Test(arguments: [false, true])
    func followLidDimsAndRestoresIndependentlyOfAutomaticLockPreference(keepDesktop: Bool) async throws {
        let (controller, platform, power, _, brightness) = setup()
        try controller.setKeepsDesktopAvailable(keepDesktop)
        await controller.start(mode: .smart, duration: .seconds(120), policy: SafetyPolicy())
        #expect(!brightness.dimmed)
        platform.lid = .closed
        await controller.reconcile()
        #expect(controller.phase == .active && brightness.dimmed)
        #expect(power.state.display == (keepDesktop ? .on : .off))
        platform.lid = .open
        await controller.reconcile()
        #expect(controller.phase == .active && !brightness.dimmed)
        #expect(power.state.display == .on)
        #expect(controller.manualRemaining == 120)
        await controller.stop()
    }

    @Test func reopeningRestoresBeforeDelayedHelperRenewal() async {
        let (controller, platform, _, transport, brightness) = setup()
        await controller.start(mode: .smart, duration: .seconds(120), policy: SafetyPolicy())
        platform.lid = .closed
        await controller.reconcile()
        #expect(brightness.dimmed)
        platform.lid = .open
        transport.delayRenew = true
        let reconcile = Task { await controller.reconcile() }
        while transport.gate == nil { await Task.yield() }
        #expect(!brightness.dimmed)
        transport.delayRenew = false
        transport.gate?.resume(); transport.gate = nil
        await reconcile.value
        await controller.stop()
    }

    @Test(arguments: [Mode.display, .closed])
    func otherModesDoNotDim(mode: Mode) async {
        let (controller, platform, _, _, brightness) = setup()
        await controller.start(mode: mode, duration: .seconds(120), policy: SafetyPolicy())
        platform.lid = .closed
        await controller.reconcile()
        #expect(controller.phase == .active && !brightness.dimmed)
        await controller.stop()
    }

    @Test(arguments: [false, true])
    func expiryAndSafetyRestoreBrightness(thermal: Bool) async {
        let (controller, platform, power, _, brightness) = setup()
        await controller.start(mode: .smart, duration: .seconds(120), policy: SafetyPolicy())
        platform.lid = .closed
        await controller.reconcile()
        #expect(brightness.dimmed)
        if thermal { platform.thermal = .serious } else { platform.time += 121 }
        await controller.reconcile()
        #expect(!brightness.dimmed && power.state == .off && platform.flag == .off)
        #expect(!controller.hasSession)
    }

    @Test func failedRestoreStillReleasesPowerAndCanRecover() async {
        let (controller, platform, power, _, brightness) = setup()
        await controller.start(mode: .smart, duration: .seconds(120), policy: SafetyPolicy())
        platform.lid = .closed
        await controller.reconcile()
        brightness.failRestore = true
        await controller.stopAndSleep()
        #expect(controller.phase == .recovery && brightness.dimmed)
        #expect(platform.flag == .off && power.state == .off && power.sleepRequests == 0)
        brightness.failRestore = false
        platform.lid = .open
        await controller.recoverAfterConfirmation()
        #expect(controller.phase == .off && !brightness.dimmed)
    }

    @Test func failedDimEndsSessionAndReleasesHelper() async {
        let (controller, platform, power, _, brightness) = setup()
        await controller.start(mode: .smart, duration: .seconds(120), policy: SafetyPolicy())
        platform.lid = .closed
        brightness.failDim = true
        await controller.reconcile()
        #expect(controller.phase == .paused && !brightness.dimmed)
        #expect(platform.flag == .off && power.state == .off)
    }

    @Test func startupRestorationFailureBlocksAdmissionWithoutRequiringHelper() async {
        let platform = TestPlatform()
        let brightness = SessionBrightness()
        brightness.dimmed = true; brightness.failRestore = true
        let controller = SessionController(clock: platform, sampler: platform,
                                           power: TestAssertions(), helper: TestTransport(platform),
                                           brightness: brightness)
        #expect(controller.phase == .recovery && !controller.canStart)
        brightness.failRestore = false
        await controller.recoverAfterConfirmation()
        #expect(controller.phase == .off && !brightness.dimmed)
    }
}
