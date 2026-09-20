import Foundation
import Observation
import ServiceManagement
import LidPilotRuntime

@MainActor @Observable final class HelperManager {
    private let service = SMAppService.daemon(plistName: HelperIdentity.plist)
    private(set) var status: SMAppService.Status = .notRegistered
    private(set) var error: String?
    var mutationsAllowed = true
    let signed = (try? HelperIdentity.ownTeam()) != nil
    var enabled: Bool { signed && status == .enabled }
    var label: String {
        guard signed else { return "Signed build required" }
        switch status {
        case .enabled: return "Approved"
        case .requiresApproval: return "Approval needed"
        case .notRegistered: return "Not installed"
        case .notFound: return "Registration needs repair"
        @unknown default: return "Unavailable"
        }
    }
    init() { refresh() }
    func refresh() {
        status = service.status
        // Approval can complete in System Settings after register() reports EPERM.
        if status == .enabled { error = nil }
    }
    func register() {
        guard mutationsAllowed else { return }
        guard signed else { error = "Helper approval requires a build signed by the LidPilot publisher."; return }
        do { try service.register(); error = nil } catch { self.error = error.localizedDescription }
        refresh()
        if status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }
    func openApproval() { if mutationsAllowed { SMAppService.openSystemSettingsLoginItems() } }
    func unregister() async throws {
        guard mutationsAllowed else { throw RuntimeFailure.unavailable("Helper changes are disabled in UI preview.") }
        refresh()
        if status == .enabled || status == .requiresApproval { try await service.unregister() }
        refresh()
        guard status == .notRegistered || status == .notFound else {
            throw RuntimeFailure.unavailable("The helper is still registered. The update cannot proceed.")
        }
    }
}
