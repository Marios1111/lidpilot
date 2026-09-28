import Foundation
import Observation
import LidPilotCore

public enum SessionPhase: String, Codable, Sendable {
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

    public private(set) var manualMode: Mode?
    public private(set) var manualDeadline: SessionDeadline?
    public private(set) var workloads = WorkloadRegistry()
    public private(set) var integrationsArmed = false
    public var onWorkloadCompletion: ((String) -> Void)?
    public private(set) var lastConfirmedOperation: String?
    private var helperDeadline: SessionDeadline?
    private var helperMode: Mode?
    private var helperGeneration: UInt64 = 0
    private var notifiedWorkloads: [String: UInt64] = [:]

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
    public var manualRemaining: Double? { manualDeadline?.remaining(at: clock.now()) }
    public var nextCheckDelay: Double {
        max(0.1, min(15, currentHolds().compactMap { $0.deadline.remaining(at: clock.now()) }.min() ?? 15))
    }
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
            let end: SessionDeadline
            if let current = manualDeadline, !current.isExpired(at: clock.now()) { end = current }
            else { end = try SessionDeadline(duration: duration, clock: clock.now()) }
            try preflight(mode: mode, policy: policy, requireOpenLid: mode.needsHelper)
            manualDeadline = end
            manualMode = mode
            self.policy = policy
            await applyRequests()
        } catch {
            if hasSession { message = error.localizedDescription }
            else { publish(.paused, error.localizedDescription) }
        }
    }

    public func armWorkloads() throws {
        guard canStart, phase != .updating else { throw RuntimeFailure.unavailable("Resolve recovery or the update before arming task hooks.") }
        // Explicit re-arm is a new admission period; active requests are preserved.
        if !hasSession { workloads.removeAll(); notifiedWorkloads.removeAll() }
        integrationsArmed = true
    }

    public func disarmWorkloads() async {
        integrationsArmed = false
        workloads.removeAgentRequests()
        notifiedWorkloads.removeAll()
        await applyRequests()
    }

    public func handleWorkload(_ event: WorkloadEvent, mode: Mode, policy: SafetyPolicy,
                               options: WorkloadOptions, explicitStart: Bool = false) async throws {
        guard canStart else { throw RuntimeFailure.unavailable(message) }
        let existing = workloads.records.first {
            $0.source == event.source && $0.sessionID == event.sessionID &&
            $0.turnID == event.turnID && $0.taskID == event.taskID
        }
        guard event.source == .command ? (explicitStart || existing != nil) : integrationsArmed else {
            throw RuntimeFailure.unavailable("Task hooks are disarmed. Arm them explicitly in Settings or with lidpilot tasks arm.")
        }
        if event.state == .working && existing == nil {
            try preflight(mode: mode, policy: policy, requireOpenLid: mode.needsHelper)
        }
        try policy.validate()
        var candidate = workloads
        guard try candidate.apply(event, mode: mode, options: options, at: clock.now()) else {
            if event.source == .command, event.state == .working,
               !workloads.activeHolds(at: clock.now()).contains(where: { $0.id == existing?.id }) {
                throw RuntimeFailure.unavailable("This command's protection has ended. Start a new request explicitly.")
            }
            return
        }
        self.policy = policy
        workloads = candidate
        await applyRequests()
        onEvent?(phase, message)
        if event.state == .working {
            let record = workloads.records.first { $0.source == event.source && $0.sessionID == event.sessionID && $0.turnID == event.turnID && $0.taskID == event.taskID }
            guard phase == .active, let record, workloads.activeHolds(at: clock.now()).contains(where: { $0.id == record.id }) else {
                throw RuntimeFailure.unavailable("The workload's protection was not confirmed. It may have been stopped or expired.")
            }
        }
        if event.state == .finished || event.state == .failed {
            let text = event.source == .command
                ? (event.state == .finished && event.exitCode == 0 ? "Command finished successfully." : "Command ended with exit status \(event.exitCode.map(String.init) ?? "unknown").")
                : (event.state == .failed ? "Agent turn failed." : (event.taskID == nil ? "Agent turn ended." : "Agent subtask ended."))
            onWorkloadCompletion?(text + (phase == .off && assertions == .off ? " LidPilot's controls are released." : " Other requests or cleanup may remain."))
        }
        if phase == .paused || phase == .recovery || phase == .unverified {
            throw RuntimeFailure.unavailable(message)
        }
    }

    private struct RequestHold {
        let mode: Mode
        let deadline: SessionDeadline
    }

    private func currentHolds() -> [RequestHold] {
        let now = clock.now()
        var result = workloads.activeHolds(at: now).map { RequestHold(mode: $0.mode, deadline: $0.deadline) }
        if let manualMode, let manualDeadline, !manualDeadline.isExpired(at: now) {
            result.append(RequestHold(mode: manualMode, deadline: manualDeadline))
        }
        return result
    }

    private func latestDeadline(_ requests: [RequestHold]) -> SessionDeadline? {
        let now = clock.now()
        return requests.max { ($0.deadline.remaining(at: now) ?? .infinity) < ($1.deadline.remaining(at: now) ?? .infinity) }?.deadline
    }

    private func preflight(mode: Mode, policy: SafetyPolicy, requireOpenLid: Bool) throws {
        try policy.validate()
        let snapshot = sampler.sample(flag: helperState?.flag ?? .unknown)
        observation = snapshot
        if let reason = policy.evaluate(snapshot: snapshot, mode: mode, clock: clock.now(), requireOpenLid: requireOpenLid) {
            throw RuntimeFailure.unavailable(Self.explanation(reason))
        }
        if mode.needsHelper && !helperAvailable {
            throw RuntimeFailure.unavailable("Approve the LidPilot helper to use this mode.")
        }
    }

    /// One arbiter feeds the existing assertion/lease path. A display request plus
    /// a closed-lid request has Smart's combined requirements, with independent ends.
    private func applyRequests() async {
        let now = clock.now()
        if manualDeadline?.isExpired(at: now) == true { manualMode = nil; manualDeadline = nil }
        workloads.expire(at: now)
        let retainedIDs = Set(workloads.records.map(\.id))
        notifiedWorkloads = notifiedWorkloads.filter { retainedIDs.contains($0.key) }
        for record in workloads.records where record.state == .idle && record.holdDeadline.isExpired(at: now) {
            if notifiedWorkloads[record.id] != record.sequence {
                notifiedWorkloads[record.id] = record.sequence
                onWorkloadCompletion?("Agent turn ended. Other requests may still be active.")
            }
        }
        let holds = currentHolds()
        guard let end = latestDeadline(holds) else {
            if hasSession {
                let reason: String
                if workloads.records.contains(where: { $0.state == .unknown }) {
                    reason = "Task status is unknown. LidPilot's controls are released."
                } else if workloads.records.contains(where: { $0.state == .waiting }) {
                    reason = "Waiting for input. Task protection is released."
                } else {
                    reason = workloads.records.isEmpty ? "Your session has ended." : "Task protection has ended."
                }
                await stopControls(reason: reason, safety: false)
            }
            return
        }
        let needsHelper = holds.contains { $0.mode.needsHelper }
        let needsDisplay = holds.contains { $0.mode != .closed }
        let mode: Mode = needsHelper ? (needsDisplay ? .smart : .closed) : .display
        let newHelperDeadline = latestDeadline(holds.filter { $0.mode.needsHelper })
        // Renew unchanged parameters through the existing immutable lease path.
        if phase == .active, requestedMode == mode, deadline == end,
           helperDeadline == newHelperDeadline { return }
        let token = advance()
        deadline = end
        requestedMode = mode
        publish(.starting, "Checking power state…")
        await enqueue { [self] in
            guard token == generation else { return }
            do {
                try preflight(mode: mode, policy: policy, requireOpenLid: mode.needsHelper && !helperMayOwn)
                guard !end.isExpired(at: clock.now()) else { throw RuntimeFailure.unavailable("The session has ended.") }
                if mode.needsHelper, let newHelperDeadline {
                    let op: WireOperation
                    if helperMayOwn {
                        op = .replace
                    } else {
                        try await cleanup(token: token)
                        guard token == generation else { return }
                        sessionID = UUID()
                        helperSessionID = sessionID
                        helperMayOwn = true
                        onOwnershipChange?(true)
                        op = .acquire
                    }
                    let response = try await helper.send(WireRequest(operation: op, sessionID: helperSessionID ?? sessionID,
                        generation: token, deadline: newHelperDeadline, policy: policy, mode: mode))
                    helperState = response
                    guard token == generation else { return }
                    guard response.success, response.leaseActive, response.ownsOverride, response.flag == .on, !response.recoveryPending else {
                        throw RuntimeFailure.unavailable(response.message)
                    }
                    helperDeadline = newHelperDeadline
                    helperMode = mode
                    helperGeneration = token
                } else {
                    try await cleanup(token: token)
                }
                guard token == generation else { return }
                guard !end.isExpired(at: clock.now()) else { throw RuntimeFailure.unavailable("The session has ended.") }
                let current = sampler.sample(flag: helperState?.flag ?? .unknown)
                if let reason = policy.evaluate(snapshot: current, mode: mode, clock: clock.now()) {
                    throw RuntimeFailure.unavailable(Self.explanation(reason))
                }
                observation = current
                assertions = try power.apply(system: true, display: Self.displayHeld(mode, lid: current.lid),
                    timeout: assertionTimeout(), displayTimeout: assertionTimeout(displayOnly: true))
                effectiveMode = mode
                publish(.active, Self.activeMessage(mode, lid: current.lid))
            } catch {
                guard token == generation else { return }
                clearRequests()
                requestedMode = nil; effectiveMode = nil
                do { try await cleanup(token: token); publish(.paused, error.localizedDescription) }
                catch { publish(.recovery, error.localizedDescription) }
            }
        }
    }

    private func assertionTimeout(displayOnly: Bool = false) -> Double {
        // Each capability lasts for its last relevant request, independently.
        // A long Closed task cannot extend a shorter display request on a stall.
        let holds = currentHolds().filter { !displayOnly || $0.mode != .closed }
        return max(0.1, min(60, holds.map { $0.deadline.remaining(at: clock.now()) ?? 60 }.max() ?? 0.1))
    }

    private func clearRequests() {
        manualMode = nil; manualDeadline = nil
        workloads.removeAll(); notifiedWorkloads.removeAll()
        integrationsArmed = false
    }

    public func stop(reason: String = "Normal macOS behavior.", safety: Bool = false) async {
        clearRequests()
        await stopControls(reason: reason, safety: safety)
    }

    private func stopControls(reason: String, safety: Bool) async {
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
        guard !reconciling, phase == .active || phase == .starting else { return }
        reconciling = true
        defer { reconciling = false }
        if let mode = requestedMode {
            let sample = sampler.sample(flag: helperState?.flag ?? .unknown)
            observation = sample
            if let reason = policy.evaluate(snapshot: sample, mode: mode, clock: clock.now()) {
                await stop(reason: Self.explanation(reason), safety: true)
                return
            }
        }
        await applyRequests()
        guard let mode = requestedMode, let deadline, phase == .active || phase == .starting else { return }
        let token = generation
        let snapshot = sampler.sample(flag: helperState?.flag ?? .unknown)
        observation = snapshot
        if let reason = policy.evaluate(snapshot: snapshot, mode: mode, clock: clock.now()) {
            await stop(reason: Self.explanation(reason), safety: true)
            return
        }
        guard phase == .active else { return }
        // Drop a Smart display hold immediately on close, before a potentially delayed XPC reply.
        if mode == .smart, snapshot.lid != .open {
            do { assertions = try power.apply(system: true, display: false, timeout: assertionTimeout()) }
            catch { await stop(reason: error.localizedDescription, safety: true); return }
        }
        var reconcileError: (any Error)?
        await enqueue { [self] in
            guard token == generation else { return }
            do {
                if mode.needsHelper {
                    let response = try await helper.send(WireRequest(operation: .renew, sessionID: helperSessionID ?? sessionID, generation: helperGeneration,
                                                                     deadline: helperDeadline, policy: policy, mode: helperMode))
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
                                             timeout: assertionTimeout(), displayTimeout: assertionTimeout(displayOnly: true))
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
            helperDeadline = nil
            helperMode = nil
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
        if phase == .active || phase == .off { lastConfirmedOperation = text }
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
