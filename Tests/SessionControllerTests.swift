import Foundation
import Testing
import LidPilotCore
@testable import LidPilotRuntime

@MainActor final class TestAssertions: PowerAssertions {
    var state = AssertionState.off
    var sleepRequests = 0
    var failRelease = false
    var systemTimeout: Double = 0
    var screenTimeout: Double = 0
    var appliedDisplayStates: [Bool] = []
    func apply(system: Bool, display: Bool, timeout: Double, displayTimeout: Double) throws -> AssertionState {
        appliedDisplayStates.append(display)
        systemTimeout = timeout; screenTimeout = displayTimeout
        state = AssertionState(system: system ? .on : .off, display: display ? .on : .off)
        return state
    }
    func release() throws -> AssertionState {
        if failRelease { throw RuntimeFailure.unavailable("assertion release failed") }
        state = .off
        return state
    }
    func observed() -> AssertionState { state }
    func sleep() throws { sleepRequests += 1 }
}

@MainActor final class TestTransport: HelperTransport {
    let platform: TestPlatform
    let engine: HelperEngine
    let client = UUID()
    var gate: CheckedContinuation<Void, Never>?
    var delayAcquire = false
    var delayRenew = false
    var delayNextInspect = false
    var replacementDelay: Duration?
    var failInspect = false
    var requests: [WireRequest] = []
    private var inFlight = 0
    private(set) var maximumInFlight = 0
    init(_ platform: TestPlatform) { self.platform = platform; engine = platform.engine() }
    func send(_ request: WireRequest) async throws -> WireReply {
        requests.append(request)
        inFlight += 1
        maximumInFlight = max(maximumInFlight, inFlight)
        defer { inFlight -= 1 }
        if delayNextInspect, request.operation == .inspect {
            delayNextInspect = false
            await withCheckedContinuation { gate = $0 }
        }
        if failInspect, request.operation == .inspect { throw RuntimeFailure.unavailable("status unavailable") }
        if (delayAcquire && request.operation == .acquire) || (delayRenew && request.operation == .renew) {
            await withCheckedContinuation { gate = $0 }
        }
        if request.operation == .replace, let replacementDelay {
            try await Task.sleep(for: replacementDelay)
        }
        return engine.handle(request, client: client)
    }
    func disconnect() { engine.disconnected(client: client) }
}

@MainActor struct SessionControllerTests {
    private func setup() -> (SessionController, TestPlatform, TestAssertions, TestTransport) {
        let platform = TestPlatform(); let power = TestAssertions(); let transport = TestTransport(platform)
        let controller = SessionController(clock: platform, sampler: platform, power: power, helper: transport)
        controller.helperAvailable = true
        return (controller, platform, power, transport)
    }

    @Test func startsOffAndDisplayDoesNotUseHelper() async {
        let (controller, _, power, transport) = setup()
        #expect(controller.phase == .off && controller.requestedMode == nil)
        await controller.start(mode: .display, duration: .seconds(3600), policy: SafetyPolicy())
        #expect(controller.phase == .active && power.state.display == .on)
        #expect(transport.requests.isEmpty)
        await controller.stop()
        #expect(controller.phase == .off && power.state == .off)
    }

    @Test(arguments: [Mode.smart, Mode.closed])
    func desktopAvailabilityKeepsBoundedDisplayHoldAcrossLidClosure(mode: Mode) async throws {
        let (controller, platform, power, _) = setup()
        #expect(!controller.keepsDesktopAvailable)
        try controller.setKeepsDesktopAvailable(true)
        #expect(controller.phase == .off && power.state == .off)
        await controller.start(mode: mode, duration: .seconds(120), policy: SafetyPolicy())
        platform.lid = .closed
        platform.time += 5
        await controller.reconcile()
        #expect(controller.phase == .active && controller.effectiveMode == mode)
        #expect(power.state.system == .on && power.state.display == .on)
        #expect(power.appliedDisplayStates.allSatisfy { $0 })
        #expect(power.screenTimeout == 60 && controller.manualRemaining == 115)
        await controller.stop()
        #expect(controller.phase == .off && power.state == .off && platform.flag == .off)
    }

    @Test(arguments: [false, true])
    func desktopAvailabilityEndsOnExpiryAndMandatorySafety(thermal: Bool) async throws {
        let (controller, platform, power, _) = setup()
        try controller.setKeepsDesktopAvailable(true)
        await controller.start(mode: .closed, duration: .seconds(10), policy: SafetyPolicy())
        #expect(power.screenTimeout == 10)
        platform.lid = .closed
        if thermal { platform.thermal = .serious } else { platform.time += 11 }
        await controller.reconcile()
        #expect(controller.phase == (thermal ? .paused : .off))
        #expect(power.state == .off && platform.flag == .off)
        #expect(controller.manualMode == nil && !controller.integrationsArmed)
    }

    @Test func desktopAvailabilityCannotChangeDuringAdmissionOrUpdate() async throws {
        let (controller, _, power, _) = setup()
        try controller.setKeepsDesktopAvailable(true)
        await controller.start(mode: .display, duration: .seconds(60), policy: SafetyPolicy())
        #expect(throws: (any Error).self) { try controller.setKeepsDesktopAvailable(false) }
        #expect(controller.keepsDesktopAvailable && power.state.display == .on)
        await controller.stop()
        try controller.armWorkloads()
        #expect(throws: (any Error).self) { try controller.setKeepsDesktopAvailable(false) }
        await controller.disarmWorkloads()
        try await controller.beginUpdate()
        #expect(throws: (any Error).self) { try controller.setKeepsDesktopAvailable(false) }
        controller.endUpdate()
        try controller.setKeepsDesktopAvailable(false)
        #expect(!controller.keepsDesktopAvailable && power.state == .off)
    }

    @Test func desktopAvailabilityDoesNotSurviveAnExplicitStopAndSleep() async throws {
        let (controller, platform, power, _) = setup()
        try controller.setKeepsDesktopAvailable(true)
        await controller.start(mode: .smart, duration: .seconds(60), policy: SafetyPolicy())
        await controller.stopAndSleep()
        #expect(power.sleepRequests == 1 && power.state == .off && platform.flag == .off)
        #expect(controller.phase == .off)
    }

    @Test func failedStatusIsUnverifiedAndDisplayRemainsIndependent() async {
        let (controller, _, power, transport) = setup()
        transport.failInspect = true
        await controller.refreshWhileOff()
        #expect(controller.phase == .unverified && power.state == .off)
        transport.failInspect = false
        await controller.refreshWhileOff()
        #expect(controller.phase == .off)
        transport.failInspect = true
        await controller.refreshWhileOff()
        await controller.start(mode: .display, duration: .seconds(60), policy: SafetyPolicy())
        #expect(controller.phase == .active && controller.effectiveMode == .display)
        #expect(transport.requests.allSatisfy { $0.operation == .inspect })
    }

    @Test func overlappingOffRefreshesShareOneInspectionAndAllowLaterRefresh() async {
        let (controller, _, _, transport) = setup()
        transport.delayNextInspect = true
        let first = Task { await controller.refreshWhileOff() }
        while transport.gate == nil { await Task.yield() }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<30 { group.addTask { await controller.refreshWhileOff() } }
        }
        #expect(transport.requests.map(\.operation) == [.inspect])
        #expect(transport.maximumInFlight == 1)
        transport.gate?.resume(); transport.gate = nil
        await first.value
        #expect(controller.phase == .off)

        await controller.refreshWhileOff()
        #expect(transport.requests.map(\.operation) == [.inspect, .inspect])
    }

    @Test(arguments: [false, true]) func startWaitsForOffInspectionAndIgnoresItsStaleReply(failInspect: Bool) async {
        let (controller, platform, power, transport) = setup()
        transport.delayNextInspect = true
        transport.failInspect = failInspect
        let refresh = Task { await controller.refreshWhileOff() }
        while transport.gate == nil { await Task.yield() }
        let start = Task { await controller.start(mode: .smart, duration: .seconds(600), policy: SafetyPolicy()) }
        while controller.requestedMode == nil { await Task.yield() }

        #expect(transport.requests.map(\.operation) == [.inspect])
        #expect(controller.helperState == nil)
        transport.gate?.resume(); transport.gate = nil
        await refresh.value; await start.value

        #expect(transport.maximumInFlight == 1)
        #expect(transport.requests.map(\.operation) == [.inspect, .acquire])
        #expect(controller.phase == .active && platform.flag == .on)
        #expect(power.state.system == .on && power.state.display == .on)
        #expect(controller.helperState?.leaseActive == true)
    }

    @Test func stopSupersedesStartQueuedBehindOffInspection() async {
        let (controller, platform, power, transport) = setup()
        transport.delayNextInspect = true
        let refresh = Task { await controller.refreshWhileOff() }
        while transport.gate == nil { await Task.yield() }
        let start = Task { await controller.start(mode: .smart, duration: .seconds(600), policy: SafetyPolicy()) }
        while controller.requestedMode == nil { await Task.yield() }
        let generation = controller.generation
        let stop = Task { await controller.stop() }
        while controller.generation == generation { await Task.yield() }

        transport.gate?.resume(); transport.gate = nil
        await refresh.value; await start.value; await stop.value

        #expect(transport.requests.map(\.operation) == [.inspect])
        #expect(controller.phase == .off && controller.requestedMode == nil)
        #expect(controller.helperState == nil)
        #expect(power.state == .off && platform.flag == .off)
    }

    @Test(arguments: [false, true]) func stopInvalidatesDelayedOffInspection(failInspect: Bool) async {
        let (controller, platform, power, transport) = setup()
        transport.delayNextInspect = true
        transport.failInspect = failInspect
        let refresh = Task { await controller.refreshWhileOff() }
        while transport.gate == nil { await Task.yield() }
        let generation = controller.generation
        let stop = Task { await controller.stop(reason: "Explicit stop.") }
        while controller.generation == generation { await Task.yield() }
        transport.gate?.resume(); transport.gate = nil
        await refresh.value; await stop.value

        #expect(controller.phase == .off && controller.message == "Explicit stop.")
        #expect(controller.helperState == nil)
        #expect(power.state == .off && platform.flag == .off)
        #expect(transport.maximumInFlight == 1)
        transport.failInspect = false
        await controller.refreshWhileOff()
        #expect(transport.requests.map(\.operation) == [.inspect, .inspect])
        #expect(controller.phase == .off)
    }

    @Test func smartCloseDropsDisplayReopenReverifiesLease() async {
        let (controller, platform, power, transport) = setup()
        await controller.start(mode: .smart, duration: .seconds(3600), policy: SafetyPolicy())
        #expect(power.state.display == .on && platform.flag == .on)
        platform.lid = .closed
        await controller.reconcile()
        #expect(power.state.display == .off && power.state.system == .on)
        platform.lid = .open
        await controller.reconcile()
        #expect(power.state.display == .on)
        #expect(transport.requests.filter { $0.operation == .renew }.count == 2)
    }

    @Test func stopWinsAgainstDelayedEnable() async {
        let (controller, platform, power, transport) = setup()
        transport.delayAcquire = true
        let start = Task { await controller.start(mode: .smart, duration: .seconds(600), policy: SafetyPolicy()) }
        while transport.gate == nil { await Task.yield() }
        let stop = Task { await controller.stop() }
        while controller.phase != .stopping { await Task.yield() }
        transport.gate?.resume(); transport.gate = nil
        await start.value; await stop.value
        #expect(controller.phase == .off && platform.flag == .off && power.state == .off)
        #expect(controller.effectiveMode == nil)
    }

    @Test func safetyWinsDuringActivationAndNeverAutoResumes() async {
        let (controller, platform, power, transport) = setup()
        transport.delayAcquire = true
        let start = Task { await controller.start(mode: .smart, duration: .seconds(600), policy: SafetyPolicy()) }
        while transport.gate == nil { await Task.yield() }
        platform.thermal = .serious
        let safety = Task { await controller.reconcile() }
        while controller.phase != .stopping { await Task.yield() }
        transport.gate?.resume(); transport.gate = nil
        await start.value; await safety.value
        #expect(controller.phase == .paused && platform.flag == .off && power.state == .off)
        platform.thermal = .nominal
        await controller.reconcile()
        #expect(controller.phase == .paused)
    }

    @Test func switchingModesKeepsDeadlineAndCleansHelper() async {
        let (controller, platform, _, _) = setup()
        await controller.start(mode: .smart, duration: .seconds(60), policy: SafetyPolicy())
        let deadline = controller.deadline
        platform.time += 20
        await controller.start(mode: .display, duration: .indefinite, policy: SafetyPolicy())
        #expect(controller.deadline == deadline && platform.flag == .off)
        #expect(controller.remaining == 40)
        platform.time += 41
        await controller.reconcile()
        #expect(controller.phase == .off)
    }

    @Test func closedModeNeverHoldsDisplayAndSleepRequiresCleanup() async {
        let (controller, platform, power, _) = setup()
        await controller.start(mode: .closed, duration: .indefinite, policy: SafetyPolicy())
        #expect(power.state.display == .off && power.state.system == .on)
        platform.failRestore = true
        await controller.stopAndSleep()
        #expect(controller.phase == .recovery && power.sleepRequests == 0)
        platform.failRestore = false
        await controller.stopAndSleep()
        #expect(controller.phase == .off && power.sleepRequests == 1)
    }

    @Test func updateBarrierRejectsActiveSessionAndBlocksActivation() async throws {
        let (controller, _, power, _) = setup()
        await controller.start(mode: .display, duration: .indefinite, policy: SafetyPolicy())
        await #expect(throws: (any Error).self) { try await controller.beginUpdate() }
        #expect(controller.phase == .active)
        await controller.stop()
        try await controller.beginUpdate()
        await controller.start(mode: .display, duration: .indefinite, policy: SafetyPolicy())
        #expect(controller.phase == .updating && power.state == .off)
        controller.endUpdate()
        #expect(controller.phase == .off)
    }

    @Test func stopWaitsForInFlightRenewalWithoutReactivation() async {
        let (controller, platform, power, transport) = setup()
        await controller.start(mode: .smart, duration: .seconds(600), policy: SafetyPolicy())
        transport.delayRenew = true
        let renewal = Task { await controller.reconcile() }
        while transport.gate == nil { await Task.yield() }
        let stop = Task { await controller.stop() }
        while controller.phase != .stopping { await Task.yield() }
        #expect(transport.requests.last?.operation == .renew)
        transport.gate?.resume(); transport.gate = nil
        await renewal.value; await stop.value
        #expect(controller.phase == .off && platform.flag == .off && power.state == .off)
    }

    @Test func invalidModeSwitchPreservesRunningSession() async {
        let (controller, _, power, _) = setup()
        await controller.start(mode: .display, duration: .seconds(600), policy: SafetyPolicy())
        let generation = controller.generation
        await controller.start(mode: .smart, duration: .seconds(600), policy: SafetyPolicy(batteryFloor: 99))
        #expect(controller.phase == .active && controller.effectiveMode == .display)
        #expect(controller.generation == generation && power.state.display == .on)
    }

    @Test func interruptedUpdateBlocksActivationSynchronously() async {
        let (controller, _, power, _) = setup()
        controller.holdInterruptedUpdate()
        await controller.start(mode: .display, duration: .indefinite, policy: SafetyPolicy())
        #expect(controller.phase == .updating && controller.updateBarrier && power.state == .off)
    }

    @Test func updateRefusesClosedLidAndRecoveryFailure() async {
        let (controller, platform, power, _) = setup()
        platform.lid = .closed
        await #expect(throws: (any Error).self) { try await controller.beginUpdate() }
        #expect(!controller.updateBarrier)
        platform.lid = .open; power.failRelease = true
        await #expect(throws: (any Error).self) { try await controller.beginUpdate() }
        #expect(!controller.updateBarrier && controller.phase == .recovery)
    }
}
