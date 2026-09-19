import Foundation
import Testing
@testable import LidPilotRuntime
import LidPilotCore

final class TestPlatform: RuntimeClock, PowerSampling, SleepFlagControlling, RecoveryStoring, @unchecked Sendable {
    var time: Double = 100
    var flag: FlagState = .off
    var power: PowerSource = .external
    var lid: LidState = .open
    var thermal: ThermalLevel = .nominal
    var record: RecoveryRecord?
    var corrupt = false
    var failRestore = false
    var failEnable = false
    var failRead = false
    var sampleLatency: Double = 0
    var writes: [Bool] = []
    var onWrite: ((Bool) -> Void)?
    var onFence: (() -> Void)?
    var failFence = false
    func withMutationFence<T>(_ operation: () throws -> T) throws -> T {
        if failFence { throw RuntimeFailure.unavailable("fence is busy") }
        onFence?()
        return try operation()
    }
    func now() -> ClockSample { ClockSample(continuousSeconds: time, wallDate: Date(timeIntervalSince1970: time), bootID: "boot") }
    func sample(flag: FlagState) -> PowerSnapshot {
        time += sampleLatency
        return PowerSnapshot(sampledAt: now(), lid: lid, power: power, batteryPercent: 70, thermal: thermal,
                      lowPowerMode: false, externalDisplayCount: 0, sleepDisabled: flag)
    }
    func read() throws -> FlagState {
        if failRead { throw RuntimeFailure.unavailable("read failed") }
        return flag
    }
    func setDisabled(_ disabled: Bool) throws {
        writes.append(disabled)
        if !disabled && failRestore { throw RuntimeFailure.unavailable("restore failed") }
        flag = disabled ? .on : .off
        onWrite?(disabled)
        if disabled && failEnable { throw RuntimeFailure.unavailable("enable failed after mutation") }
    }
    func load() throws -> RecoveryRecord? {
        if corrupt { throw RuntimeFailure.unavailable("corrupt") }
        return record
    }
    func save(_ record: RecoveryRecord) throws { self.record = record; corrupt = false }
    func clear() throws { record = nil }
    func engine() -> HelperEngine { HelperEngine(driver: self, sampler: self, journal: self, clock: self, build: "1") }
    func acquire(generation: UInt64 = 1, seconds: Double = 600, session: UUID = UUID()) throws -> WireRequest {
        WireRequest(operation: .acquire, sessionID: session, generation: generation,
                    deadline: try SessionDeadline(duration: .seconds(seconds), clock: now()),
                    policy: SafetyPolicy(), mode: .smart)
    }
}

struct HelperEngineTests {
    @Test func sampledReadingsAreComparedWithAFreshClock() throws {
        let platform = TestPlatform(); platform.sampleLatency = 0.001
        let engine = platform.engine(); let client = UUID()
        var request = try platform.acquire()
        #expect(engine.handle(request, client: client).success)
        request.operation = .renew
        #expect(engine.handle(request, client: client).success)
    }

    @Test func refusesUnownedOverrideWithoutAnyMutation() throws {
        let platform = TestPlatform(); platform.flag = .on
        let result = platform.engine().handle(try platform.acquire(), client: UUID())
        #expect(!result.success && !result.ownsOverride)
        #expect(platform.writes.isEmpty)
    }

    @Test func journalsBeforeEnableAndVerifiesRelease() throws {
        let platform = TestPlatform(); let engine = platform.engine(); let client = UUID()
        platform.onWrite = { _ in #expect(platform.record != nil) }
        let request = try platform.acquire()
        #expect(engine.handle(request, client: client).leaseActive)
        let result = engine.handle(WireRequest(operation: .release, sessionID: request.sessionID, generation: 2), client: client)
        #expect(result.success && result.flag == .off && !result.ownsOverride)
        #expect(platform.writes == [true, false])
        #expect(platform.record == nil)
    }

    @Test func watchdogExpiresFrozenClientAndDoesNotRearm() throws {
        let platform = TestPlatform(); let engine = platform.engine(); let client = UUID()
        let request = try platform.acquire()
        #expect(engine.handle(request, client: client).success)
        platform.time += 61
        engine.watchdog()
        #expect(platform.flag == .off)
        var renewal = request; renewal.operation = .renew
        #expect(!engine.handle(renewal, client: client).success)
        #expect(platform.writes == [true, false])
    }

    @Test func delayedEnableCannotExtendHardDeadline() throws {
        let platform = TestPlatform(); let engine = platform.engine()
        platform.onWrite = { enabled in if enabled { platform.time += 10 } }
        let result = engine.handle(try platform.acquire(seconds: 5), client: UUID())
        #expect(!result.success && !result.leaseActive && result.flag == .off)
        #expect(platform.writes == [true, false])
    }

    @Test func stopTombstoneRejectsDelayedActivation() throws {
        let platform = TestPlatform(); let engine = platform.engine(); let client = UUID()
        let delayed = try platform.acquire()
        let stop = WireRequest(operation: .release, sessionID: delayed.sessionID, generation: 2)
        #expect(engine.handle(stop, client: client).success)
        #expect(!engine.handle(delayed, client: client).success)
        #expect(platform.writes.isEmpty)
    }

    @Test func failedEnableStillRestoresActualMutation() throws {
        let platform = TestPlatform(); platform.failEnable = true
        let result = platform.engine().handle(try platform.acquire(), client: UUID())
        #expect(!result.success && result.flag == .off && !result.recoveryPending)
        #expect(platform.writes == [true, false])
    }

    @Test func failedRestorationRemainsVisibleAndRetries() throws {
        let platform = TestPlatform(); let engine = platform.engine(); let client = UUID()
        let request = try platform.acquire()
        #expect(engine.handle(request, client: client).success)
        platform.failRestore = true
        let result = engine.handle(WireRequest(operation: .release, sessionID: request.sessionID, generation: 2), client: client)
        #expect(!result.success && result.recoveryPending && result.ownsOverride)
        #expect(platform.record != nil)
        platform.failRestore = false
        engine.watchdog()
        #expect(platform.flag == .off && platform.record == nil)
    }

    @Test func helperRestartRecoversBeforeNewRequests() throws {
        let platform = TestPlatform()
        platform.record = RecoveryRecord(sessionID: UUID(), generation: 1, bootID: "previous-boot")
        platform.flag = .on
        platform.engine().watchdog()
        #expect(platform.flag == .off && platform.record == nil)
        #expect(platform.writes == [false])
    }

    @Test func corruptJournalRequiresExplicitRecovery() throws {
        let platform = TestPlatform(); platform.corrupt = true; platform.flag = .on
        let engine = platform.engine(); let client = UUID()
        #expect(!engine.handle(try platform.acquire(), client: client).success)
        #expect(platform.writes.isEmpty)
        let result = engine.handle(WireRequest(operation: .recover, sessionID: UUID(), generation: 2), client: client)
        #expect(result.success && result.flag == .off && !result.recoveryPending)
    }

    @Test func renewCannotChangeDeadlineAndDisconnectRestores() throws {
        let platform = TestPlatform(); let engine = platform.engine(); let client = UUID()
        var request = try platform.acquire(seconds: 30)
        #expect(engine.handle(request, client: client).success)
        request.operation = .renew
        request.deadline = try SessionDeadline(duration: .seconds(600), clock: platform.now())
        #expect(!engine.handle(request, client: client).success)
        engine.disconnected(client: client)
        #expect(platform.flag == .off)
    }

    @Test func thermalAndChargerChangesStopIndependently() throws {
        for thermal in [false, true] {
            let platform = TestPlatform(); let engine = platform.engine()
            #expect(engine.handle(try platform.acquire(), client: UUID()).success)
            if thermal { platform.thermal = .serious } else { platform.power = .battery }
            engine.watchdog()
            #expect(platform.flag == .off)
        }
    }

    @Test func transientFenceTimeoutDoesNotLatchFalseRecovery() {
        for phase in [RecoveryPhase?.none, .some(.prepared), .some(.enableInFlight)] {
            let platform = TestPlatform(); let engine = platform.engine()
            if let phase { platform.record = RecoveryRecord(sessionID: UUID(), generation: 1, bootID: "boot", phase: phase) }
            platform.failFence = true
            engine.watchdog()
            platform.failFence = false
            let result = engine.handle(WireRequest(operation: .inspect, sessionID: UUID(), generation: 1), client: UUID())
            #expect(result.success && !result.recoveryPending && platform.record == nil)
            #expect(platform.writes.isEmpty)
        }
    }

    @Test func idleFenceTimeoutDoesNotInventOwnedRecovery() {
        let platform = TestPlatform(); let engine = platform.engine()
        engine.watchdog()
        platform.failFence = true; engine.watchdog()
        platform.failFence = false; engine.watchdog()
        let result = engine.handle(WireRequest(operation: .inspect, sessionID: UUID(), generation: 1), client: UUID())
        #expect(result.success && !result.recoveryPending && platform.writes.isEmpty)
    }

    @Test func ownedRestorationRetriesAfterFenceBecomesAvailable() throws {
        let platform = TestPlatform(); let engine = platform.engine()
        #expect(engine.handle(try platform.acquire(), client: UUID()).success)
        platform.time += 61; platform.failFence = true
        engine.watchdog()
        #expect(platform.flag == .on && platform.record != nil)
        platform.failFence = false
        engine.watchdog()
        #expect(platform.flag == .off && platform.record == nil)
    }

    @Test func inspectChecksExpiredLeaseBeforeAnswering() throws {
        let platform = TestPlatform(); let engine = platform.engine(); let client = UUID()
        let request = try platform.acquire()
        #expect(engine.handle(request, client: client).success)
        platform.time += 61
        let reply = engine.handle(WireRequest(operation: .inspect, sessionID: UUID(), generation: 1), client: client)
        #expect(reply.flag == .off && !reply.leaseActive)
        #expect(reply.health?.watchdogAvailable == true)
    }

    @Test func incompleteJournalPhasesNeverClaimAnUnownedOverride() {
        for phase in [RecoveryPhase.prepared, .enableInFlight] {
            for flag in [FlagState.off, .on, .unknown] {
                let platform = TestPlatform(); platform.flag = flag
                platform.record = RecoveryRecord(sessionID: UUID(), generation: 1, bootID: "boot", phase: phase)
                let reply = platform.engine().handle(WireRequest(operation: .inspect, sessionID: UUID(), generation: 1), client: UUID())
                #expect(platform.writes.isEmpty)
                #expect(!reply.ownsOverride)
                #expect(reply.recoveryPending == (flag != .off))
                #expect((platform.record == nil) == (flag == .off))
            }
        }
    }

    @Test func oldChildSettlesBeforeRestartReadsOrRestores() {
        for phase in [RecoveryPhase.enableInFlight, .enabledVerified] {
            let platform = TestPlatform()
            platform.record = RecoveryRecord(sessionID: UUID(), generation: 1, bootID: "boot", phase: phase)
            platform.onFence = { platform.flag = .on }
            let result = platform.engine().handle(WireRequest(operation: .inspect, sessionID: UUID(), generation: 1), client: UUID())
            if phase == .enabledVerified {
                #expect(result.flag == .off && !result.recoveryPending)
                #expect(platform.writes == [false])
            } else {
                #expect(result.recoveryPending && platform.record != nil)
                #expect(platform.writes.isEmpty)
            }
        }
    }

    @Test func enableHasDurableInFlightAndVerifiedPhases() throws {
        let platform = TestPlatform()
        platform.onWrite = { enabled in
            if enabled { #expect(platform.record?.phase == .enableInFlight) }
        }
        #expect(platform.engine().handle(try platform.acquire(), client: UUID()).success)
        #expect(platform.record?.phase == .enabledVerified)
    }

    @Test func differentClientCannotReleaseOrRenewLease() throws {
        let platform = TestPlatform(); let engine = platform.engine()
        let request = try platform.acquire()
        #expect(engine.handle(request, client: UUID()).success)
        let result = engine.handle(WireRequest(operation: .release, sessionID: request.sessionID, generation: 2), client: UUID())
        #expect(!result.success && result.leaseActive)
    }
}
