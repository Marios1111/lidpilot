import Foundation
import Observation
import ServiceManagement
import LidPilotRuntime

@MainActor @Observable final class HelperManager {
    private let configuration: HelperIdentity.Configuration?
    private let service: SMAppService?
    private(set) var status: SMAppService.Status = .notRegistered
    private(set) var error: String?
    var mutationsAllowed = true
    let signed = (try? HelperIdentity.ownTeam()) != nil
    var enabled: Bool { configuration != nil && signed && status == .enabled }
    var label: String {
        guard configuration != nil else { return "Unsupported app identity" }
        guard signed else { return "Signed build required" }
        switch status {
        case .enabled: return "Approved"
        case .requiresApproval: return "Approval needed"
        case .notRegistered: return "Not installed"
        case .notFound: return "Registration needs repair"
        @unknown default: return "Unavailable"
        }
    }
    init() {
        let selectedConfiguration = HelperIdentity.applicationConfiguration()
        configuration = selectedConfiguration
        service = selectedConfiguration.map { SMAppService.daemon(plistName: $0.daemonPlistName) }
        refresh()
    }
    func refresh() {
        guard let service else { status = .notFound; return }
        status = service.status
        // Approval can complete in System Settings after register() reports EPERM.
        if status == .enabled { error = nil }
    }
    func register() {
        guard mutationsAllowed else { return }
        guard let service else { error = "This app bundle does not have a recognized LidPilot helper identity."; return }
        guard signed else { error = "Helper approval requires a build signed by the LidPilot publisher."; return }
        do { try service.register(); error = nil } catch { self.error = error.localizedDescription }
        refresh()
        if status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }
    func openApproval() { if mutationsAllowed, service != nil { SMAppService.openSystemSettingsLoginItems() } }
    func unregister() async throws {
        guard mutationsAllowed else { throw RuntimeFailure.unavailable("Helper changes are disabled in UI preview.") }
        guard let service else {
            throw RuntimeFailure.unavailable("This app bundle does not have a recognized LidPilot helper identity.")
        }
        refresh()
        if status == .enabled || status == .requiresApproval { try await service.unregister() }
        refresh()
        guard status == .notRegistered || status == .notFound else {
            throw RuntimeFailure.unavailable("The helper is still registered. The update cannot proceed.")
        }
    }
}
