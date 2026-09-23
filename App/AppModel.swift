import AppKit
import Observation
import ServiceManagement
import UserNotifications
import LidPilotCore
import LidPilotRuntime

enum DurationChoice: String, CaseIterable, Identifiable {
    case halfHour, hour, twoHours, fourHours, custom, until, indefinite
    var id: Self { self }
    var title: String {
        switch self {
        case .halfHour: "30 min"
        case .hour: "1 hour"
        case .twoHours: "2 hours"
        case .fourHours: "4 hours"
        case .custom: "Custom…"
        case .until: "Until a time…"
        case .indefinite: "Until I stop"
        }
    }
}

@MainActor @Observable final class AppModel {
    let controller: SessionController
    let helper = HelperManager()
    let diagnostics: DiagnosticsStore
    let isPreview: Bool
    var updater: UpdateCoordinator?
    var selectedMode: Mode { didSet { defaults.set(selectedMode.rawValue, forKey: "preferredMode") } }
    var duration: DurationChoice { didSet { defaults.set(duration.rawValue, forKey: "duration") } }
    var customMinutes: Int {
        didSet {
            if (1...10_080).contains(customMinutes) { defaults.set(customMinutes, forKey: "customMinutes") }
        }
    }
    var untilDate = Date().addingTimeInterval(3600)
    var batteryFloor: Int { didSet { defaults.set(batteryFloor, forKey: "batteryFloor") } }
    var allowBattery: Bool { didSet { defaults.set(allowBattery, forKey: "allowBattery") } }
    var respectLowPower: Bool { didSet { defaults.set(respectLowPower, forKey: "respectLowPower") } }
    var notify: Bool { didSet { defaults.set(notify, forKey: "notifications") } }
    var onboardingComplete: Bool { didSet { defaults.set(onboardingComplete, forKey: "onboardingComplete") } }
    var showRecoveryConfirmation = false
    var loginError: String?
    var launchAtLogin = SMAppService.mainApp.status == .enabled
    var showOnboarding = false
    var exportPreview = ""
    private let defaults: UserDefaults
    private let observer: StateObserver?
    private var heartbeat: Task<Void, Never>?
    private var heartbeatGeneration = 0

    init(defaults store: UserDefaults = .standard) {
        #if DEBUG
        isPreview = ProcessInfo.processInfo.environment["LIDPILOT_UI_TESTING"] == "1"
        #else
        isPreview = false
        #endif
        diagnostics = DiagnosticsStore(persist: !isPreview)
        observer = isPreview ? nil : StateObserver()
        helper.mutationsAllowed = !isPreview
        let defaults = isPreview ? UserDefaults(suiteName: "com.lidpilot.ui-testing")! : store
        self.defaults = defaults
        selectedMode = Mode(rawValue: defaults.string(forKey: "preferredMode") ?? "smart") ?? .smart
        duration = DurationChoice(rawValue: defaults.string(forKey: "duration") ?? "hour") ?? .hour
        let savedMinutes = defaults.integer(forKey: "customMinutes")
        customMinutes = (1...10_080).contains(savedMinutes) ? savedMinutes : 90
        let savedFloor = defaults.integer(forKey: "batteryFloor")
        batteryFloor = [10, 20, 30].contains(savedFloor) ? savedFloor : 20
        allowBattery = defaults.bool(forKey: "allowBattery")
        respectLowPower = defaults.object(forKey: "respectLowPower") as? Bool ?? true
        notify = defaults.bool(forKey: "notifications")
        onboardingComplete = defaults.bool(forKey: "onboardingComplete")
        let clock = SystemClock()
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unconfigured"
        #if DEBUG
        if isPreview {
            let machine = PreviewMachine()
            controller = SessionController(clock: machine, sampler: machine, power: PreviewAssertions(), helper: PreviewTransport(machine: machine))
        } else {
            controller = SessionController(clock: clock, sampler: SystemPowerSampler(clock: clock),
                                           power: NativeAssertions(), helper: XPCTransport(build: build),
                                           recoveryHint: defaults.bool(forKey: "cleanupPending"))
        }
        #else
        controller = SessionController(clock: clock, sampler: SystemPowerSampler(clock: clock),
                                       power: NativeAssertions(), helper: XPCTransport(build: build),
                                       recoveryHint: defaults.bool(forKey: "cleanupPending"))
        #endif
        controller.helperAvailable = closedLidReady
        controller.onOwnershipChange = { [weak self] owned in self?.defaults.set(owned, forKey: "cleanupPending") }
        controller.onEvent = { [weak self] phase, message in self?.sessionChanged(phase, message) }
        observer?.onChange = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                #if LIDPILOT_PROFILE
                PerformanceTrace.event("reconcile_trigger", fields: ["source": "observer", "phase": String(describing: self.controller.phase)])
                #endif
                self.refreshHelper()
                if self.controller.hasSession { await self.controller.reconcile() }
                else { await self.controller.refreshWhileOff() }
            }
        }
        observer?.onSleep = { [weak self] in
            guard let self, self.controller.hasSession else { return }
            Task { await self.controller.stop(reason: "Stopped for macOS sleep or a user-session change.", safety: true) }
        }
        updater = UpdateCoordinator(model: self)
        Task { await controller.refreshWhileOff() }
    }

    var policy: SafetyPolicy { SafetyPolicy(batteryFloor: batteryFloor, allowBattery: allowBattery, respectLowPowerMode: respectLowPower) }
    var closedLidReady: Bool { isPreview || helper.enabled }
    var sessionDuration: SessionDuration {
        switch duration {
        case .halfHour: .seconds(1800)
        case .hour: .seconds(3600)
        case .twoHours: .seconds(7200)
        case .fourHours: .seconds(14400)
        case .custom: .seconds(Double(customMinutes) * 60)
        case .until: .until(untilDate)
        case .indefinite: .indefinite
        }
    }

    func chooseMode(_ mode: Mode) {
        selectedMode = mode
        if controller.hasSession {
            Task {
                await controller.start(mode: mode, duration: sessionDuration, policy: policy)
                if let requested = controller.requestedMode { selectedMode = requested }
            }
        }
    }
    func start() {
        guard onboardingComplete else { showOnboarding = true; return }
        refreshHelper()
        Task { await controller.start(mode: selectedMode, duration: sessionDuration, policy: policy) }
    }
    func refreshHelper() { helper.refresh(); controller.helperAvailable = closedLidReady }
    func approveHelper() { guard !isPreview else { return }; helper.register(); refreshHelper() }
    func setLogin(_ enabled: Bool) {
        guard !isPreview else { return }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch { loginError = error.localizedDescription }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    func requestNotifications() {
        guard !isPreview else { notify = true; return }
        Task {
            do { notify = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
            catch { notify = false }
        }
    }
    func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "LidPilot-diagnostics.txt"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            do { try exportPreview.write(to: url, atomically: true, encoding: .utf8) }
            catch { diagnostics.record(.off, "Diagnostic export failed.") }
        }
    }
    func stopObserving() { heartbeat?.cancel(); observer?.stop() }

    private func sessionChanged(_ phase: SessionPhase, _ message: String) {
        diagnostics.record(phase, message)
        if controller.hasSession {
            if heartbeat == nil {
                heartbeatGeneration += 1
                let heartbeatToken = heartbeatGeneration
                heartbeat = Task { [weak self] in
                    while let self, self.controller.hasSession, !Task.isCancelled {
                        let delay = max(0.1, min(15, self.controller.remaining ?? 15))
                        do { try await Task.sleep(for: .seconds(delay)) } catch { break }
                        #if LIDPILOT_PROFILE
                        PerformanceTrace.event("heartbeat", fields: ["stage": "fire", "delay_s": String(delay), "phase": String(describing: self.controller.phase)])
                        PerformanceTrace.event("reconcile_trigger", fields: ["source": "heartbeat", "phase": String(describing: self.controller.phase)])
                        #endif
                        await self.controller.reconcile()
                    }
                    if self?.heartbeatGeneration == heartbeatToken { self?.heartbeat = nil }
                }
            }
        } else { heartbeatGeneration += 1; heartbeat?.cancel(); heartbeat = nil }
        if !isPreview, notify, phase == .paused || phase == .recovery || (phase == .off && message == "Your session has ended.") {
            let content = UNMutableNotificationContent()
            content.title = phase == .recovery ? "Cleanup needs attention" : (phase == .paused ? "LidPilot paused" : "Session finished")
            content.body = message
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            Task { try? await UNUserNotificationCenter.current().add(request) }
        }
    }
}
