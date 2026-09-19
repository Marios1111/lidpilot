import Foundation
import IOKit.pwr_mgt
import LidPilotCore

public struct AssertionState: Equatable, Sendable {
    public let system: FlagState
    public let display: FlagState
    public init(system: FlagState, display: FlagState) { self.system = system; self.display = display }
    public static let off = AssertionState(system: .off, display: .off)
}

@MainActor public protocol PowerAssertions: AnyObject {
    func apply(system: Bool, display: Bool, timeout: Double) throws -> AssertionState
    func release() throws -> AssertionState
    func observed() -> AssertionState
    func sleep() throws
}

@MainActor public final class NativeAssertions: PowerAssertions {
    private var systemID: IOPMAssertionID?
    private var displayID: IOPMAssertionID?
    public init() {}

    public func apply(system: Bool, display: Bool, timeout: Double) throws -> AssertionState {
        guard timeout.isFinite, timeout > 0, timeout <= 60 else {
            throw RuntimeFailure.unavailable("Invalid assertion lease duration.")
        }
        // On lid close, drop the display assertion before doing any other work.
        if !display { try remove(&displayID) }
        if !system { try remove(&systemID) }
        if system { try maintain(&systemID, type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString, timeout: timeout) }
        if display { try maintain(&displayID, type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString, timeout: timeout) }
        let state = observed()
        guard state.system == (system ? .on : .off), state.display == (display ? .on : .off) else {
            throw RuntimeFailure.unavailable("LidPilot's assertions could not be verified.")
        }
        return state
    }

    public func release() throws -> AssertionState {
        // Attempt both releases even if the first fails.
        var failure: (any Error)?
        do { try remove(&displayID) } catch { failure = error }
        do { try remove(&systemID) } catch { failure = error }
        if let failure { throw failure }
        return observed()
    }

    public func observed() -> AssertionState {
        AssertionState(system: level(systemID), display: level(displayID))
    }

    public func sleep() throws {
        guard observed() == .off else { throw RuntimeFailure.unavailable("Release LidPilot's assertions before sleeping.") }
        let connection = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
        guard connection != 0 else { throw RuntimeFailure.unavailable("macOS sleep service is unavailable.") }
        defer { IOServiceClose(connection) }
        guard IOPMSleepSystem(connection) == kIOReturnSuccess else {
            throw RuntimeFailure.unavailable("macOS did not accept the sleep request.")
        }
    }

    private func maintain(_ id: inout IOPMAssertionID?, type: CFString, timeout: Double) throws {
        if let existing = id {
            guard level(existing) == .on,
                  IOPMAssertionSetProperty(existing, kIOPMAssertionTimeoutKey as CFString, timeout as CFNumber) == kIOReturnSuccess else {
                throw RuntimeFailure.unavailable("An assertion expired or could not be renewed.")
            }
        } else {
            var newID: IOPMAssertionID = 0
            guard IOPMAssertionCreateWithDescription(type, "LidPilot session" as CFString,
                    "User-requested, time-limited keep-awake session" as CFString, nil, nil,
                    timeout, kIOPMAssertionTimeoutActionRelease as CFString, &newID) == kIOReturnSuccess else {
                throw RuntimeFailure.unavailable("macOS could not create the keep-awake assertion.")
            }
            id = newID
        }
    }

    private func remove(_ id: inout IOPMAssertionID?) throws {
        guard let existing = id else { return }
        let result = IOPMAssertionRelease(existing)
        // The OS may already have released an expired, bounded assertion.
        guard result == kIOReturnSuccess || result == kIOReturnNotFound else {
            throw RuntimeFailure.unavailable("An assertion could not be released.")
        }
        guard IOPMAssertionCopyProperties(existing)?.takeRetainedValue() == nil else {
            throw RuntimeFailure.unavailable("An assertion remains after release.")
        }
        id = nil
    }

    private func level(_ id: IOPMAssertionID?) -> FlagState {
        guard let id else { return .off }
        guard let properties = IOPMAssertionCopyProperties(id)?.takeRetainedValue() as? [String: Any],
              let value = properties[kIOPMAssertionLevelKey] as? NSNumber else { return .unknown }
        return value.intValue == kIOPMAssertionLevelOn ? .on : .off
    }
}
