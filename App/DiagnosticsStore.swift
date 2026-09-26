import Foundation
import Observation
import LidPilotRuntime

@MainActor @Observable final class DiagnosticsStore {
    typealias Entry = DiagnosticEntry
    private var log: DiagnosticLog
    var entries: [Entry] { log.entries }
    var storageError: String? { log.storageError }

    init(persist: Bool = true) {
        let namespace = HelperIdentity.applicationConfiguration()?.userStateDirectoryName
        let url: URL?
        if persist, let namespace,
           let support = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true) {
            url = support.appendingPathComponent(namespace, isDirectory: true).appendingPathComponent("diagnostics.json")
        } else {
            url = nil
        }
        log = DiagnosticLog(fileURL: url)
    }

    func record(_ phase: SessionPhase, _ message: String) {
        log.record(state: phase.rawValue, message: message)
    }
    func clear() { log.clear() }

    func report(controller: SessionController, helper: HelperManager) -> String {
        log.refresh()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        let snapshot = controller.observation
        let lines = ["LidPilot \(version) — local diagnostic preview", "State: \(controller.phase.rawValue)",
                     "Helper: \(helper.label)", "Lid: \(snapshot?.lid.rawValue ?? "unknown")",
                     "Power: \(snapshot?.power.rawValue ?? "unknown")", "Thermal: \(snapshot?.thermal.rawValue ?? "unknown")",
                     "System assertion: \(controller.assertions.system.rawValue)",
                     "Display assertion: \(controller.assertions.display.rawValue)",
                     "Sleep flag: \(controller.helperState?.flag.rawValue ?? "unknown")",
                     "Physical panel power: not measured", "", "Recent events (last 50):"]
        return (lines + entries.suffix(50).map { "\($0.date.formatted(.iso8601)) | \($0.state) | \($0.message)" }).joined(separator: "\n")
    }
}
