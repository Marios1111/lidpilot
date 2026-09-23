import Foundation
import Observation
import LidPilotCore

public enum SessionPhase: String, Sendable {
    case off, starting, active, stopping, paused, unverified, recovery, updating
}

@MainActor @Observable public final class SessionController {
    public private(set) var phase: SessionPhase = .off
    public private(set) var requestedMode: Mode?
    public private(set) var effectiveMode: Mode?
    public private(set) var deadline: SessionDeadline?
    public private(set) var observation: PowerSnapshot?
    public private(set) var assertions = AssertionState.off
    public private(set) var helperState: WireReply?
    public private(set) var message = "Normal macOS behavior."
    public private(set) var generation: UInt64 = 1
    public private(set) var updateBarrier = false
    public var helperAvailable = false
    public var onEvent: ((SessionPhase, String) -> Void)?
    public var onOwnershipChange: ((Bool) -> Void)?

    private let clock: any RuntimeClock
    private let sampler: any PowerSampling
    private let power: any PowerAssertions
    private let helper: any HelperTransport
    private var sessionID = UUID()
    private var helperSessionID: UUID?
    private var helperMayOwn = false
    private var policy = SafetyPolicy()
    private var operation: Task<Void, Never>?
    private var reconciling = false
    private var cleanupVerified = true

    public init(clock: any RuntimeClock, sampler: any PowerSampling,
                power: any PowerAssertions, helper: any HelperTransport, recoveryHint: Bool = false) {
        self.clock = clock; self.sampler = sampler; self.power = power; self.helper = helper
        helperMayOwn = recoveryHint
        if recoveryHint { phase = .recovery; message = "Checking cleanup from the previous run." }
    }

    public var remaining: Double? { deadline?.remaining(at: clock.now()) }
    public var canStart: Bool { !updateBarrier && phase != .recovery && phase != .stopping }
    public var hasSession: Bool { requestedMode != nil || phase == .starting || phase == .active }

    public func refreshWhileOff() async {
        guard !hasSession, phase != .stopping, !updateBarrier else { return }
        let token = generation
        observation = sampler.sample(flag: helperState?.flag ?? .unknown)
        if helperAvailable {
            do {
                let response = try await helper.send(WireRequest(operation: .inspect, sessionID: sessionID, generation: token))
                guard generation == token, !hasSession else { return }
                helperState = response
                observation = response.sample ?? observation
                guard response.success || response.ownsOverride || response.recoveryPending else {
                    throw RuntimeFailure.unavailable(response.message)
                }
                helperMayOwn = response.ownsOverride || response.recoveryPending
                if helperMayOwn { phase = .recovery; message = response.message }
                else if phase == .recovery || phase == .unverified, cleanupVerified, assertions == .off {
                    publish(.off, "LidPilot's controls are off.")
                }
                onOwnershipChange?(helperMayOwn)
            } catch {
                guard generation == token else { return }
                if helperMayOwn { publish(.recovery, error.localizedDescription) }
                else { publish(.unverified, "Helper status is unverified: \(error.localizedDescription) Keep Screen On remains available.") }
            }
        }
    }

    public func start(mode: Mode, duration: SessionDuration, policy: SafetyPolicy) async {
        guard canStart else { return }
        do {
            try policy.validate()
            // Switching mode changes behavior, not the existing end condition.
            if !hasSession { deadline = try SessionDeadline(duration: duration, clock: clock.now()) }
        } catch {
            if hasSession { message = "Choose a valid safety policy before switching mode." }
            else { publish(.paused, "Choose a valid session duration and safety policy.") }
            return
        }
        let token = advance()
        self.policy = policy
        requestedMode = mode
        publish(.starting, "Checking power state…")
        await enqueue { [self] in
            guard token == generation else { return }
            do {
                try await cleanup(token: token)
                guard token == generation else { return }
                guard let deadline, !deadline.isExpired(at: clock.now()) else { throw RuntimeFailure.unavailable("The session has ended.") }
                let snapshot = sampler.sample(flag: helperState?.flag ?? .unknown)
                observation = snapshot
                if let reason = policy.evaluate(snapshot: snapshot, mode: mode, clock: clock.now(), requireOpenLid: mode.needsHelper) {
                    throw RuntimeFailure.unavailable(Self.explanation(reason))
                }
                sessionID = UUID()
                if mode.needsHelper {
                    guard helperAvailable else { throw RuntimeFailure.unavailable("Approve the LidPilot helper to use this mode.") }
                    helperSessionID = sessionID
                    helperMayOwn = true
                    onOwnershipChange?(true)
                    let response = try await helper.send(WireRequest(operation: .acquire, sessionID: sessionID, generation: token,
                                                                     deadline: deadline, policy: policy, mode: mode))
                    helperState = response
                    guard token == generation else { return }
                    guard response.success, response.leaseActive, response.ownsOverride, response.flag == .on, !response.recoveryPending else {
                        throw RuntimeFailure.unavailable(response.message)
                    }
                }
                guard token == generation else { return }
                guard !deadline.isExpired(at: clock.now()) else { throw RuntimeFailure.unavailable("The session has ended.") }
                let current = sampler.sample(flag: helperState?.flag ?? .unknown)
                if let reason = policy.evaluate(snapshot: current, mode: mode, clock: clock.now()) {
                    throw RuntimeFailure.unavailable(Self.explanation(reason))
                }
                observation = current
                assertions = try power.apply(system: true, display: Self.displayHeld(mode, lid: current.lid),
                                             timeout: min(60, deadline.remaining(at: clock.now()) ?? 60))
                effectiveMode = mode
                publish(.active, Self.activeMessage(mode, lid: current.lid))
            } catch {
                guard token == generation else { return }
                requestedMode = nil
                effectiveMode = nil
                do { try await cleanup(token: token); publish(.paused, error.localizedDescription) }
                catch { publish(.recovery, error.localizedDescription) }
            }
        }
    }

    public func stop(reason: String = "Normal macOS behavior.", safety: Bool = false) async {
        let token = advance()
        requestedMode = nil
        effectiveMode = nil
        publish(.stopping, "Releasing LidPilot's controls…")
        await enqueue { [self] in
            guard token == generation else { return }
            do {
                try await cleanup(token: token)
                guard token == generation else { return }
                deadline = nil
                publish(safety ? .paused : .off, reason)
            } catch { if token == generation { publish(.recovery, error.localizedDescription) } }
        }
    }

    public func reconcile() async {
        #if LIDPILOT_PROFILE
        PerformanceTrace.event("reconcile", fields: ["stage": "begin", "phase": String(describing: phase), "already_reconciling": String(reconciling)])
        defer { PerformanceTrace.event("reconcile", fields: ["stage": "end", "phase": String(describing: phase)]) }
        #endif
        guard !reconciling, let mode = requestedMode, let deadline,
              phase == .active || phase == .starting else { return }
        reconciling = true
        defer { reconciling = false }
        let token = generation
        let snapshot = sampler.sample(flag: helperState?.flag ?? .unknown)
        observation = snapshot
        if deadline.isExpired(at: clock.now()) {
            await stop(reason: "Your session has ended.")
            return
        }
        if let reason = policy.evaluate(snapshot: snapshot, mode: mode, clock: clock.now()) {
            await stop(reason: Self.explanation(reason), safety: true)
            return
        }
        guard phase == .active else { return }
        // Drop a Smart display hold immediately on close, before a potentially delayed XPC reply.
        if mode == .smart, snapshot.lid != .open {
            do { assertions = try power.apply(system: true, display: false, timeout: min(60, deadline.remaining(at: clock.now()) ?? 60)) }
            catch { await stop(reason: error.localizedDescription, safety: true); return }
        }
        var reconcileError: (any Error)?
        await enqueue { [self] in
            guard token == generation else { return }
            do {
                if mode.needsHelper {
                    let response = try await helper.send(WireRequest(operation: .renew, sessionID: sessionID, generation: token,
                                                                     deadline: deadline, policy: policy, mode: mode))
                    guard token == generation else { return }
                    helperState = response
                    guard response.success, response.leaseActive, response.ownsOverride, response.flag == .on, !response.recoveryPending else {
                        throw RuntimeFailure.unavailable(response.message)
                    }
                }
                guard token == generation else { return }
                let current = sampler.sample(flag: helperState?.flag ?? .unknown)
                guard !deadline.isExpired(at: clock.now()) else { throw RuntimeFailure.unavailable("Your session has ended.") }
                if let reason = policy.evaluate(snapshot: current, mode: mode, clock: clock.now()) {
                    throw RuntimeFailure.unavailable(Self.explanation(reason))
                }
                observation = current
                assertions = try power.apply(system: true, display: Self.displayHeld(mode, lid: current.lid),
                                             timeout: min(60, deadline.remaining(at: clock.now()) ?? 60))
                message = Self.activeMessage(mode, lid: current.lid)
            } catch { reconcileError = error }
        }
        if let reconcileError, token == generation {
            await stop(reason: reconcileError.localizedDescription, safety: true)
        }
    }

    public func recoverAfterConfirmation() async {
        guard !hasSession, !updateBarrier, helperAvailable else { return }
        let token = advance()
        publish(.stopping, "Checking recovery…")
        await enqueue { [self] in
            do {
                assertions = try power.release()
                let response = try await helper.send(WireRequest(operation: .recover, sessionID: sessionID, generation: token))
                guard token == generation else { return }
                helperState = response
                guard response.success, response.flag == .off, !response.ownsOverride, !response.recoveryPending else {
                    throw RuntimeFailure.unavailable(response.message)
                }
                helperMayOwn = false
                onOwnershipChange?(false)
                publish(.off, "Recovery verified. Normal sleep policy restored.")
            } catch { if token == generation { publish(.recovery, error.localizedDescription) } }
        }
    }

    public func stopAndSleep() async {
        guard !updateBarrier else { return }
        await stop()
        guard phase == .off, assertions == .off, !helperMayOwn else { return }
        do { try power.sleep() } catch { message = error.localizedDescription }
    }

    public func beginUpdate() async throws {
        guard !hasSession, phase == .off || phase == .paused, !updateBarrier else {
            throw RuntimeFailure.unavailable("Turn LidPilot Off before installing an update.")
        }
        updateBarrier = true
        let token = advance()
        publish(.updating, "Preparing a safe update…")
        var failure: (any Error)?
        await enqueue { [self] in
            do {
                try await cleanup(token: token)
                guard token == generation, sampler.sample(flag: helperState?.flag ?? .unknown).lid == .open else {
                    throw RuntimeFailure.unavailable("Keep the lid open while installing an update.")
                }
            } catch { failure = error }
        }
        if let failure { endUpdate(error: failure.localizedDescription); throw failure }
    }

    /// Called synchronously during launch before Sparkle or user actions can run.
    public func holdInterruptedUpdate() {
        guard !hasSession else { return }
        updateBarrier = true
        publish(.updating, "Checking an interrupted update…")
    }

    public func endUpdate(error: String? = nil) {
        updateBarrier = false
        publish(helperMayOwn || !cleanupVerified || assertions != .off ? .recovery : .off, error ?? "Normal macOS behavior.")
    }

    private func cleanup(token: UInt64) async throws {
        cleanupVerified = false
        var releaseError: (any Error)?
        do { assertions = try power.release() } catch { assertions = power.observed(); releaseError = error }
        if helperMayOwn {
            guard helperAvailable else { throw RuntimeFailure.unavailable("Helper cleanup is unverified. Reconnect the helper to recover.") }
            let response = try await helper.send(WireRequest(operation: .release, sessionID: helperSessionID ?? sessionID, generation: token))
            helperState = response
            guard response.success, !response.ownsOverride, !response.recoveryPending, !response.leaseActive else {
                throw RuntimeFailure.unavailable(response.message)
            }
            helperMayOwn = false
            helperSessionID = nil
            onOwnershipChange?(false)
        }
        if let releaseError { throw releaseError }
        guard assertions == .off else { throw RuntimeFailure.unavailable("Assertion cleanup is unverified.") }
        cleanupVerified = true
    }

    private func enqueue(_ body: @escaping @MainActor () async -> Void) async {
        let previous = operation
        let task = Task { @MainActor in
            await previous?.value
            await body()
        }
        operation = task
        await task.value
    }

    private func advance() -> UInt64 { generation += 1; return generation }
    private func publish(_ phase: SessionPhase, _ text: String) {
        self.phase = phase
        message = text
        onEvent?(phase, text)
    }
    private static func displayHeld(_ mode: Mode, lid: LidState) -> Bool {
        mode == .display || (mode == .smart && lid == .open)
    }
    private static func activeMessage(_ mode: Mode, lid: LidState) -> String {
        if mode == .display { return "Mac and screen kept available. Brightness stays under your control." }
        if mode == .smart, lid == .open { return "Screen available. Ready for the lid to close." }
        return "Mac kept running. Display follows macOS policy."
    }
    public static func explanation(_ reason: SafetyReason) -> String {
        switch reason {
        case .thermal: return "Paused because macOS reports elevated thermal pressure. Restart when conditions improve."
        case .battery: return "Paused at your battery cutoff."
        case .unplugged: return "Paused after switching to battery power."
        case .lowPower: return "Paused for Low Power Mode on battery."
        case .lidUnknown: return "Open the lid so LidPilot can verify a safe starting state."
        case .deadline: return "Your session has ended."
        case .externalChange: return "Another controller changed the sleep policy."
        case .helperUnavailable: return "The helper is unavailable. Cleanup needs verification."
        case .unavailable: return "Power or safety readings are unavailable. Restart after they recover."
        }
    }
}
