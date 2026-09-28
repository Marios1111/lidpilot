import Foundation
import Testing
import LidPilotCore
@testable import LidPilotRuntime

@MainActor struct WorkloadControllerTests {
    func setup() -> (SessionController, TestPlatform, TestAssertions, TestTransport) {
        let platform = TestPlatform(), assertions = TestAssertions()
        let transport = TestTransport(platform)
        let controller = SessionController(clock: platform, sampler: platform, power: assertions, helper: transport)
        controller.helperAvailable = true
        return (controller, platform, assertions, transport)
    }
    func event(_ platform: TestPlatform, id: String, sequence: UInt64 = 1, state: WorkloadState = .working,
               source: WorkloadSource = .command, exit: Int? = nil) -> WorkloadEvent {
        WorkloadEvent(eventID: UUID().uuidString, source: source, adapterVersion: "1", sessionID: id,
                      turnID: id, sequence: sequence, timestamp: platform.now().wallDate, state: state, exitCode: exit)
    }

    @Test func finishedCommandPreservesLectureAndReleasesOnlyClosedHold() async throws {
        let (c, p, a, t) = setup()
        await c.start(mode: .display, duration: .seconds(3600), policy: SafetyPolicy())
        let lecture = c.manualDeadline
        try await c.handleWorkload(event(p, id: "build"), mode: .closed, policy: SafetyPolicy(), options: WorkloadOptions(), explicitStart: true)
        #expect(c.effectiveMode == .smart && p.flag == .on && a.state.display == .on)
        try await c.handleWorkload(event(p, id: "build", sequence: 2, state: .finished, exit: 0), mode: .closed, policy: SafetyPolicy(), options: WorkloadOptions())
        #expect(c.effectiveMode == .display && c.manualDeadline == lecture)
        #expect(p.flag == .off && a.state.display == .on)
        #expect(t.requests.contains { $0.operation == .release })
    }

    @Test func finishingOneOfTwoClosedTasksNeverDropsOtherLeaseWithLidClosed() async throws {
        let (c, p, _, t) = setup()
        try await c.handleWorkload(event(p, id: "first"), mode: .closed, policy: SafetyPolicy(), options: WorkloadOptions(), explicitStart: true)
        p.time += 2
        try await c.handleWorkload(event(p, id: "second"), mode: .closed, policy: SafetyPolicy(), options: WorkloadOptions(), explicitStart: true)
        p.lid = .closed
        try await c.handleWorkload(event(p, id: "first", sequence: 2, state: .finished, exit: 0), mode: .closed, policy: SafetyPolicy(), options: WorkloadOptions())
        await c.reconcile()
        #expect(c.phase == .active && c.effectiveMode == .closed && p.flag == .on)
        #expect(t.requests.filter { $0.operation == .acquire }.count == 1)
        #expect(!t.requests.contains { $0.operation == .release })
    }

    @Test func expiredLectureLeavesTaskAndDropsDisplayWithoutNewOpenLidStart() async throws {
        let (c, p, a, _) = setup()
        await c.start(mode: .display, duration: .seconds(10), policy: SafetyPolicy())
        try await c.handleWorkload(event(p, id: "task"), mode: .closed, policy: SafetyPolicy(), options: WorkloadOptions(), explicitStart: true)
        p.time += 11; p.lid = .closed
        await c.reconcile()
        #expect(c.manualMode == nil && c.phase == .active && c.effectiveMode == .closed)
        #expect(a.state.display == .off && p.flag == .on)
    }

    @Test func stopDisarmsHooksAndLateHeartbeatCannotRestart() async throws {
        let (c, p, a, _) = setup()
        try c.armWorkloads()
        try await c.handleWorkload(event(p, id: "agent", source: .codex), mode: .display, policy: SafetyPolicy(), options: WorkloadOptions())
        await c.stop()
        #expect(!c.integrationsArmed)
        await #expect(throws: (any Error).self) {
            try await c.handleWorkload(event(p, id: "agent", sequence: 2, source: .codex), mode: .display, policy: SafetyPolicy(), options: WorkloadOptions())
        }
        await #expect(throws: (any Error).self) {
            try await c.handleWorkload(event(p, id: "wrapper", sequence: 2), mode: .display, policy: SafetyPolicy(), options: WorkloadOptions())
        }
        #expect(c.phase == .off && a.state == .off)
    }

    @Test func explicitRestartAfterExpiryGetsNewDeadlineBeforeHeartbeat() async throws {
        let (c, p, _, _) = setup()
        await c.start(mode: .display, duration: .seconds(10), policy: SafetyPolicy())
        p.time += 11
        await c.start(mode: .display, duration: .seconds(300), policy: SafetyPolicy())
        #expect(c.phase == .active && c.manualRemaining == 300)
    }

    @Test func assertionCapabilitiesHaveIndependentTimeouts() async throws {
        let (c, p, a, _) = setup()
        await c.start(mode: .display, duration: .seconds(10), policy: SafetyPolicy())
        try await c.handleWorkload(event(p, id: "build"), mode: .closed, policy: SafetyPolicy(), options: WorkloadOptions(), explicitStart: true)
        #expect(a.systemTimeout == 60 && a.screenTimeout == 10)
    }

    @Test func disarmingAgentHooksPreservesCommandAndManualRequests() async throws {
        let (c, p, _, _) = setup()
        await c.start(mode: .display, duration: .seconds(300), policy: SafetyPolicy())
        try c.armWorkloads()
        try await c.handleWorkload(event(p, id: "agent", source: .codex), mode: .display, policy: SafetyPolicy(), options: WorkloadOptions())
        try await c.handleWorkload(event(p, id: "command"), mode: .closed, policy: SafetyPolicy(), options: WorkloadOptions(), explicitStart: true)
        await c.disarmWorkloads()
        #expect(!c.integrationsArmed && c.manualMode == .display && c.phase == .active)
        #expect(c.workloads.records.count == 1 && c.workloads.records[0].source == .command)
        #expect(c.effectiveMode == .smart)
    }

    @Test func safetyAndUpdateBarrierApplyToEveryRequest() async throws {
        let (c, p, a, _) = setup()
        try c.armWorkloads()
        try await c.handleWorkload(event(p, id: "agent", source: .codex), mode: .display, policy: SafetyPolicy(), options: WorkloadOptions())
        p.thermal = .serious
        await c.reconcile()
        #expect(c.phase == .paused && !c.integrationsArmed && a.state == .off)
        p.thermal = .nominal
        await c.stop()
        try await c.beginUpdate()
        await #expect(throws: (any Error).self) {
            try await c.handleWorkload(event(p, id: "build"), mode: .display, policy: SafetyPolicy(), options: WorkloadOptions(), explicitStart: true)
        }
        #expect(c.phase == .updating && a.state == .off)
    }

    @Test func delayedTaskActivationCannotReportSuccessAfterStop() async throws {
        let (c, p, a, t) = setup()
        t.delayAcquire = true
        let pending = Task { try await c.handleWorkload(event(p, id: "build"), mode: .closed, policy: SafetyPolicy(), options: WorkloadOptions(), explicitStart: true) }
        while t.gate == nil { await Task.yield() }
        let stop = Task { await c.stop() }
        while c.phase != .stopping { await Task.yield() }
        t.gate?.resume(); t.gate = nil
        await #expect(throws: (any Error).self) { try await pending.value }
        await stop.value
        #expect(c.phase == .off && p.flag == .off && a.state == .off)
    }

    @Test func waitingAndStaleTasksReleaseWithoutInventingCompletion() async throws {
        let (c, p, a, _) = setup()
        try c.armWorkloads()
        let options = WorkloadOptions(waitingGrace: 30, settlingInterval: 3, staleAfter: 60)
        try await c.handleWorkload(event(p, id: "agent", source: .codex), mode: .display, policy: SafetyPolicy(), options: options)
        try await c.handleWorkload(event(p, id: "agent", sequence: 2, state: .waiting, source: .codex), mode: .display, policy: SafetyPolicy(), options: options)
        p.time += 31
        await c.reconcile()
        #expect(c.phase == .off && c.workloads.records.first?.state == .waiting && a.state == .off)
        try await c.handleWorkload(event(p, id: "agent", sequence: 3, source: .codex), mode: .display, policy: SafetyPolicy(), options: options)
        p.time += 61
        await c.reconcile()
        #expect(c.phase == .off && c.workloads.records.first?.state == .unknown)
    }

    @Test func helperReplacementCannotAcquireOrReplayOrBypassSafety() throws {
        let p = TestPlatform(); let engine = p.engine(); let client = UUID(), session = UUID()
        let deadline = try SessionDeadline(duration: .seconds(300), clock: p.now())
        func request(_ operation: WireOperation, _ generation: UInt64) -> WireRequest {
            WireRequest(operation: operation, sessionID: session, generation: generation, deadline: deadline, policy: SafetyPolicy(), mode: .closed)
        }
        #expect(!engine.handle(request(.replace, 2), client: client).success)
        #expect(p.flag == .off)
        #expect(engine.handle(request(.acquire, 3), client: client).success)
        p.sampleLatency = 0.001
        p.lid = .closed
        #expect(engine.handle(request(.replace, 4), client: client).success)
        #expect(!engine.handle(request(.replace, 4), client: client).success)
        #expect(!engine.handle(request(.replace, 5), client: UUID()).success)
        p.thermal = .serious
        #expect(!engine.handle(request(.replace, 5), client: client).success)
        #expect(p.flag == .off)
    }
}
