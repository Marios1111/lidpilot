import Foundation
import LidPilotCore

/// All calls run on the helper's one serial executor. No async suspension occurs during mutations.
public final class HelperEngine {
    private struct Lease {
        let client: UUID
        let session: UUID
        let generation: UInt64
        let deadline: SessionDeadline
        let policy: SafetyPolicy
        let mode: Mode
        var expires: Double
    }
    private let driver: any SleepFlagControlling
    private let sampler: any PowerSampling
    private let journal: any RecoveryStoring
    private let clock: any RuntimeClock
    private let build: String
    private var lease: Lease?
    private var initialized = false
    private var owns = false
    private var recoveryPending = false
    private var lastGeneration: [UUID: UInt64] = [:]
    private var lastMessage = "Off"

    public init(driver: any SleepFlagControlling, sampler: any PowerSampling,
                journal: any RecoveryStoring, clock: any RuntimeClock, build: String) {
        self.driver = driver; self.sampler = sampler; self.journal = journal
        self.clock = clock; self.build = build
    }

    public func handle(_ request: WireRequest, client: UUID) -> WireReply {
        bootstrap()
        do {
            try request.validate()
            if request.operation == .inspect { return reply(success: !recoveryPending) }
            let previous = lastGeneration[client] ?? 0
            guard request.generation >= previous else { throw failure("Stale request rejected.") }
            // Keep this bounded even when multiple signed app instances reconnect.
            guard lastGeneration[client] != nil || lastGeneration.count < 64 else {
                throw failure("Too many helper connections; retry after recovery.")
            }
            switch request.operation {
            case .inspect: break
            case .acquire:
                guard request.generation > previous else { throw failure("Replayed activation rejected.") }
                lastGeneration[client] = request.generation
                try acquire(request, client: client)
            case .renew:
                try renew(request, client: client)
            case .release:
                guard lease == nil || lease?.client == client else { throw failure("Another client owns the lease.") }
                if let lease {
                    guard lease.session == request.sessionID, request.generation >= lease.generation else {
                        throw failure("Session ownership does not match.")
                    }
                }
                lastGeneration[client] = request.generation
                try restore()
            case .recover:
                guard lease == nil else { throw failure("Stop the current session before recovery.") }
                guard sampler.sample(flag: .unknown).lid == .open else {
                    throw failure("Open the lid before recovery.")
                }
                lastGeneration[client] = request.generation
                // This endpoint is used only after an explicit ambiguity warning in the app.
                try journal.save(RecoveryRecord(sessionID: request.sessionID, generation: request.generation,
                                                bootID: clock.now().bootID))
                owns = true
                try restore()
            }
            return reply(success: true)
        } catch {
            lastMessage = error.localizedDescription
            return reply(success: false)
        }
    }

    public func watchdog() {
        bootstrap()
        if recoveryPending, owns {
            do { try restore() } catch { lastMessage = error.localizedDescription }
            return
        }
        guard let current = lease else { return }
        do {
            let flag = try driver.read()
            let snapshot = sampler.sample(flag: flag)
            let now = clock.now()
            if now.continuousSeconds >= current.expires || current.deadline.isExpired(at: now) ||
                current.policy.evaluate(snapshot: snapshot, mode: current.mode, clock: now) != nil || flag != .on {
                try restore()
                lastMessage = "Session ended by the helper safety watchdog."
            }
        } catch {
            // Loss of observability is a stop condition, not permission to extend the lease.
            do { try restore() } catch { lastMessage = error.localizedDescription }
        }
    }

    public func disconnected(client: UUID) {
        if lease?.client == client {
            do { try restore() } catch { lastMessage = error.localizedDescription }
        }
        lastGeneration.removeValue(forKey: client)
    }

    private func bootstrap() {
        guard !initialized else { return }
        initialized = true
        do {
            if try journal.load() != nil {
                owns = true
                try restore()
                lastMessage = "Recovered an interrupted LidPilot session."
            }
        } catch {
            recoveryPending = true
            lastMessage = "Recovery required: \(error.localizedDescription)"
        }
    }

    private func acquire(_ request: WireRequest, client: UUID) throws {
        guard lease == nil, !owns, !recoveryPending else { throw failure("Cleanup is required before starting.") }
        guard let mode = request.mode, let policy = request.policy, let deadline = request.deadline else {
            throw failure("Activation parameters are missing.")
        }
        let flag = try driver.read()
        guard flag == .off else {
            throw failure(flag == .on ? "Another controller already prevents sleep." : "Sleep state is unknown.")
        }
        let snapshot = sampler.sample(flag: flag)
        let now = clock.now()
        guard deadline.bootID == now.bootID, !deadline.isExpired(at: now) else { throw failure("The session deadline has passed.") }
        if let reason = policy.evaluate(snapshot: snapshot, mode: mode, clock: now, requireOpenLid: true) {
            throw failure("Cannot start: \(reason.rawValue).")
        }
        try journal.save(RecoveryRecord(sessionID: request.sessionID, generation: request.generation, bootID: now.bootID))
        owns = true
        recoveryPending = true
        do {
            try driver.setDisabled(true)
            let verifiedFlag = try driver.read()
            let verifiedSnapshot = sampler.sample(flag: verifiedFlag)
            let verifiedTime = clock.now()
            guard verifiedFlag == .on, !deadline.isExpired(at: verifiedTime), verifiedTime.continuousSeconds < now.continuousSeconds + 60,
                  policy.evaluate(snapshot: verifiedSnapshot, mode: mode, clock: verifiedTime) == nil else {
                throw failure("Activation could not be verified within the session's safety limits.")
            }
            lease = Lease(client: client, session: request.sessionID, generation: request.generation,
                          deadline: deadline, policy: policy, mode: mode,
                          expires: min(now.continuousSeconds + 60, verifiedTime.continuousSeconds + (deadline.remaining(at: verifiedTime) ?? 60)))
            recoveryPending = false
            lastMessage = "Sleep override verified; physical panel state is not measured."
        } catch {
            let activationError = error
            do { try restore() } catch { throw failure("Activation failed and cleanup remains unverified.") }
            throw activationError
        }
    }

    private func renew(_ request: WireRequest, client: UUID) throws {
        guard let current = lease, current.client == client, current.session == request.sessionID,
              current.generation == request.generation, request.deadline == current.deadline,
              request.policy == current.policy, request.mode == current.mode else {
            throw failure("Lease identity or immutable session parameters do not match.")
        }
        watchdog()
        guard lease != nil else { throw failure("The lease expired or safety requires a new session.") }
        let now = clock.now()
        lease?.expires = min(now.continuousSeconds + 60,
                             now.continuousSeconds + (current.deadline.remaining(at: now) ?? 60))
        lastMessage = "Lease renewed and observed state verified."
    }

    private func restore() throws {
        lease = nil
        guard owns else {
            if recoveryPending { throw failure("Recovery ownership is ambiguous; explicit recovery is required.") }
            lastMessage = "LidPilot has no owned override."
            return
        }
        recoveryPending = true
        // Even after a failed read, our durable intent gives authority to attempt restoration.
        try driver.setDisabled(false)
        guard try driver.read() == .off else { throw failure("Normal sleep policy could not be verified.") }
        try journal.clear()
        owns = false
        recoveryPending = false
        lastMessage = "LidPilot's sleep override is off and cleanup is verified."
    }

    private func reply(success: Bool) -> WireReply {
        let flag = (try? driver.read()) ?? .unknown
        return WireReply(helperBuild: build, flag: flag, ownsOverride: owns, recoveryPending: recoveryPending,
                         leaseActive: lease != nil, message: lastMessage,
                         success: success && flag != .unknown, sample: sampler.sample(flag: flag))
    }

    private func failure(_ message: String) -> RuntimeFailure { .unavailable(message) }
}
