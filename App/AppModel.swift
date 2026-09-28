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
    let updateOwnership: UpdateOwnership
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
    var cliEnabled: Bool { didSet { defaults.set(cliEnabled, forKey: "cliEnabled"); configureControl() } }
    var workloadMode: Mode { didSet { defaults.set(workloadMode.rawValue, forKey: "workloadMode") } }
    var waitingGrace: Double { didSet { defaults.set(waitingGrace, forKey: "waitingGrace") } }
    var staleAfter: Double { didSet { defaults.set(staleAfter, forKey: "staleAfter") } }
    var showAgentControls: Bool { didSet { defaults.set(showAgentControls, forKey: "showAgentControls") } }
    var hookInstallations: [WorkloadSource: HookConfiguration.Installation] = [:]
    var hookSetupErrors: [WorkloadSource: String] = [:]
    var lastHookReceived: [WorkloadSource: Date] = [:]
    var agentSetupMessage: String?
    var changingAgentTasks = false
    private(set) var controlAvailable = false
    var controlError: String?
    var openPanel: (() -> Void)?
    var openAgentSettings: (() -> Void)?
    var onStatusChange: (() -> Void)?
    var shortcuts: GlobalShortcuts!
    private var controlServer: LocalControlServer?
    private var hookRouter = HookRouter()
    private let defaults: UserDefaults
    private let observer: StateObserver?
    private var heartbeat: Task<Void, Never>?
    private var heartbeatDue: Double?
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
        updateOwnership = UpdateOwnership(defaults: defaults)
        let previewControl = isPreview && ProcessInfo.processInfo.environment["LIDPILOT_CONTROL_TESTING"] == "1"
        cliEnabled = previewControl || defaults.bool(forKey: "cliEnabled")
        showAgentControls = defaults.object(forKey: "showAgentControls") as? Bool ?? true
        workloadMode = Mode(rawValue: defaults.string(forKey: "workloadMode") ?? "closed") ?? .closed
        let waiting = defaults.double(forKey: "waitingGrace")
        waitingGrace = (30...600).contains(waiting) ? waiting : 120
        let stale = defaults.double(forKey: "staleAfter")
        staleAfter = (60...1800).contains(stale) ? stale : 900
        selectedMode = Mode(rawValue: defaults.string(forKey: "preferredMode") ?? "smart") ?? .smart
        duration = DurationChoice(rawValue: defaults.string(forKey: "duration") ?? "hour") ?? .hour
        let savedMinutes = defaults.integer(forKey: "customMinutes")
        customMinutes = (1...10_080).contains(savedMinutes) ? savedMinutes : 90
        let savedFloor = defaults.integer(forKey: "batteryFloor")
        batteryFloor = [10, 20, 30].contains(savedFloor) ? savedFloor : 20
        allowBattery = defaults.bool(forKey: "allowBattery")
        respectLowPower = defaults.object(forKey: "respectLowPower") as? Bool ?? true
        notify = defaults.bool(forKey: "notifications")
        onboardingComplete = previewControl || defaults.bool(forKey: "onboardingComplete")
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
        controller.onWorkloadCompletion = { [weak self] message in self?.notifyWorkload(message) }
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
        shortcuts = GlobalShortcuts(defaults: defaults, enabled: !isPreview) { [weak self] action in
            guard let self else { return }
            switch action {
            case .openPanel: self.openPanel?()
            case .toggleSession:
                if self.controller.hasSession || self.controller.integrationsArmed { Task { await self.controller.stop() } } else { self.start() }
            case .smart: self.chooseMode(.smart)
            case .display: self.chooseMode(.display)
            case .closed: self.chooseMode(.closed)
            }
        }
        configureControl()
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
        if controller.manualMode != nil {
            Task {
                await controller.start(mode: mode, duration: sessionDuration, policy: policy)
                if let manual = controller.manualMode { selectedMode = manual }
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
    func copyStatus() {
        let snapshot = controller.observation
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let lines = [
            "LidPilot \(version) (\(build)) — status snapshot",
            "State: \(controller.phase.rawValue)",
            "Requested mode: \(controller.requestedMode?.title ?? "None")",
            "Effective mode: \(controller.effectiveMode?.title ?? "None")",
            "Status: \(controller.message)",
            "Helper: \(helper.label)",
            "Lid (last observation): \(snapshot?.lid.rawValue ?? "unknown")",
            "Power (last observation): \(snapshot?.power.rawValue ?? "unknown")",
            "Thermal (last observation): \(snapshot?.thermal.rawValue ?? "unknown")",
            "System assertion: \(controller.assertions.system.rawValue)",
            "Display assertion: \(controller.assertions.display.rawValue)",
            "Sleep override (last read-back): \(controller.helperState?.flag.rawValue ?? "unknown")",
            "Physical panel power: not measured"
        ]
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }

    func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "LidPilot-diagnostics.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do { try exportPreview.write(to: url, atomically: true, encoding: .utf8) }
            catch { diagnostics.record(.off, "Diagnostic export failed.") }
        }
    }
    func diagnosticReport() -> String {
        let report = ControlReply(code: .success, message: controller.message, status: ControlStatus(controller: controller),
                                  diagnostics: Array(diagnostics.entries.suffix(50)))
        return (try? report.encoded()).flatMap { String(data: $0, encoding: .utf8) } ?? "Could not encode diagnostics."
    }
    func installCLI() {
        let panel = NSOpenPanel()
        panel.title = "Choose a folder for the lidpilot command"
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        let executable = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/lidpilot-cli")
        do { try CLIFileOperations.install(executable: executable, directory: directory); controlError = "CLI link installed. Enable local CLI control to use it." }
        catch { controlError = error.localizedDescription }
    }
    func stopObserving() { heartbeat?.cancel(); observer?.stop(); controlServer?.stop(); shortcuts.stop() }

    static let agentSources: [WorkloadSource] = [.codex, .claude]
    var hookExecutable: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/lidpilot-cli") }
    func hookConfigURL(_ source: WorkloadSource) -> URL {
        if let path = defaults.string(forKey: "hookConfig.\(source.rawValue)") { return URL(fileURLWithPath: path) }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(source == .codex ? ".codex/hooks.json" : ".claude/settings.json")
    }
    func refreshHookSetup() {
        // Mock UI never inspects or edits the user's agent configuration.
        guard !isPreview else { return }
        for source in Self.agentSources {
            do {
                hookInstallations[source] = try CLIFileOperations.hookInstallation(at: hookConfigURL(source), source: source, executable: hookExecutable)
                hookSetupErrors[source] = nil
            } catch {
                hookInstallations[source] = nil
                hookSetupErrors[source] = "Cannot read this configuration safely. Choose your agent's config folder or repair the file."
            }
        }
    }
    func chooseHookConfig(_ source: WorkloadSource) {
        guard !isPreview else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose the \(source == .codex ? "Codex" : "Claude Code") configuration folder"
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let url = folder.appendingPathComponent(source == .codex ? "hooks.json" : "settings.json")
        defaults.set(url.path, forKey: "hookConfig.\(source.rawValue)")
        agentSetupMessage = nil
        refreshHookSetup()
    }
    func configureAgent(_ source: WorkloadSource, install: Bool) {
        guard !isPreview, !controller.integrationsArmed, !controller.hasSession, !controller.updateBarrier,
              let version = HookSignal.versions[source] else { return }
        do {
            guard FileManager.default.isExecutableFile(atPath: hookExecutable.path) else { throw ControlError.unavailable }
            try CLIFileOperations.configureHooks(at: hookConfigURL(source), source: source, version: version,
                executable: hookExecutable, install: install)
            if install { cliEnabled = true }
            agentSetupMessage = install
                ? "Connection installed. Review the hooks in your agent, then turn on Agent Tasks and start a new local turn."
                : "LidPilot's hooks were removed. Your other hooks are unchanged."
        } catch {
            agentSetupMessage = "Could not change the connection: \(error.localizedDescription) Open your agent once to create its configuration folder, or choose that folder below."
        }
        refreshHookSetup()
    }

    var canEnableAgentTasks: Bool {
        onboardingComplete && cliEnabled && controlAvailable && controller.canStart &&
            (!workloadMode.needsHelper || closedLidReady)
    }
    var agentTaskStatus: String {
        let active = controller.protectedWorkloads.filter { $0.source != .command }.count
        if active > 0 { return "\(active) \(active == 1 ? "task" : "tasks") keeping Mac awake" }
        guard controller.integrationsArmed else { return "Off · no agent protection" }
        let records = controller.workloads.records.filter { $0.source != .command }
        if controller.phase == .starting, !records.isEmpty { return "Starting task protection…" }
        if records.contains(where: { $0.state == .unknown }) { return "Task status unknown · protection released" }
        if records.contains(where: { $0.state == .waiting }) { return "Waiting for you · protection released" }
        return lastHookReceived.isEmpty ? "On · waiting for first event" : "On · waiting for next task"
    }
    var agentTaskHint: String {
        if !onboardingComplete { return "Finish Welcome & Help to enable agent tasks." }
        if !cliEnabled { return "Connect your agent once to enable this switch." }
        if !controlAvailable { return controlError ?? "Local connection unavailable. Check Agent Tasks settings." }
        if workloadMode.needsHelper && !closedLidReady { return "Enable the helper in Settings for \(workloadMode.title)." }
        if !controller.canStart { return controller.message }
        if lastHookReceived.isEmpty && controller.integrationsArmed && !controller.workloads.records.contains(where: { $0.source != .command }) {
            return "Start a new local turn in your agent. No event received yet."
        }
        return "Task behavior: \(workloadMode.title)"
    }

    var workloadOptions: WorkloadOptions {
        WorkloadOptions(waitingGrace: waitingGrace, settlingInterval: 3, staleAfter: staleAfter, maximumDuration: 28_800)
    }

    func armTasks(_ armed: Bool) {
        guard !changingAgentTasks else { return }
        if armed {
            do {
                guard canEnableAgentTasks else { controlError = agentTaskHint; return }
                guard !controller.integrationsArmed else { return }
                try controller.armWorkloads(); hookRouter.reset(); controlError = nil
                lastHookReceived.removeAll()
                onStatusChange?()
            } catch { controlError = error.localizedDescription }
        } else {
            hookRouter.reset()
            changingAgentTasks = true
            Task {
                await controller.disarmWorkloads()
                changingAgentTasks = false
                onStatusChange?()
            }
        }
    }

    private func configureControl() {
        controlAvailable = false
        guard cliEnabled else {
            controlServer?.stop(); controlServer = nil
            if controller.integrationsArmed { armTasks(false) }
            return
        }
        let previewControl = isPreview && ProcessInfo.processInfo.environment["LIDPILOT_CONTROL_TESTING"] == "1"
        guard !isPreview || previewControl else { controlAvailable = true; return }
        let channel = previewControl ? "preview" : (HelperIdentity.applicationConfiguration()?.isProduction == true ? "production" : "development")
        if controlServer == nil {
            controlServer = LocalControlServer { [weak self] request in
                guard let self else { return ControlReply(code: .unavailable, message: "LidPilot is closing.") }
                return await self.handleControl(request)
            }
        }
        do { try controlServer?.start(path: LocalControl.path(channel: channel)); controlAvailable = true; controlError = nil }
        catch { controlError = error.localizedDescription }
    }

    func handleControl(_ request: ControlRequest) async -> ControlReply {
        func reply(_ code: ControlCode, _ text: String? = nil, diagnostics entries: [DiagnosticEntry]? = nil) -> ControlReply {
            ControlReply(code: code, message: text ?? controller.message, status: ControlStatus(controller: controller), diagnostics: entries)
        }
        guard cliEnabled else { return reply(.blocked, "CLI control is disabled.") }
        do { try request.validate() } catch { return reply(.invalidInput) }
        if request.operation == .hook, let signal = request.hook { lastHookReceived[signal.source] = Date() }
        if request.operation == .status || request.operation == .diagnostics {
            if controller.hasSession { await controller.reconcile() } else { await controller.refreshWhileOff() }
            return reply(.success, diagnostics: request.operation == .diagnostics ? Array(diagnostics.entries.suffix(50)) : nil)
        }
        if request.operation == .stop {
            hookRouter.reset()
            await controller.stop()
            return reply(controller.phase == .off ? .success : .unverified)
        }
        guard onboardingComplete else { return reply(.approvalRequired, "Complete LidPilot's welcome screen first.") }
        guard controller.canStart else { return reply(.blocked) }
        refreshHelper()
        let mode = request.mode ?? workloadMode
        if [.start, .taskStart, .arm].contains(request.operation), mode.needsHelper, !closedLidReady {
            return reply(.approvalRequired, "Approve the helper in LidPilot Settings before starting closed-lid work.")
        }
        do {
            switch request.operation {
            case .start:
                // The CLI owns the same manual request as the menu-bar Start.
                // Its existing deadline is preserved by mode changes.
                let before = controller.generation
                await controller.start(mode: mode, duration: .seconds(request.seconds!), policy: policy)
                guard controller.phase == .active, controller.manualMode == mode, controller.generation >= before else { return reply(resultCode) }
            case .arm:
                if !controller.integrationsArmed {
                    try controller.armWorkloads(); hookRouter.reset(); lastHookReceived.removeAll()
                    onStatusChange?()
                }
            case .disarm: await controller.disarmWorkloads(); hookRouter.reset(); onStatusChange?()
            case .taskStart, .taskEvent:
                let options = WorkloadOptions(waitingGrace: waitingGrace, settlingInterval: 3, staleAfter: 60,
                                              maximumDuration: request.seconds ?? 28_800)
                try await controller.handleWorkload(request.event!, mode: mode, policy: policy, options: options,
                                                    explicitStart: request.operation == .taskStart)
            case .hook:
                guard controller.integrationsArmed else { return reply(.blocked, "Task hooks are disarmed.") }
                let events = try hookRouter.events(for: request.hook!, workloads: controller.workloads.records)
                for event in events { try await controller.handleWorkload(event, mode: workloadMode, policy: policy, options: workloadOptions) }
            default: return reply(.invalidInput)
            }
            return reply(.success)
        } catch is WorkloadError {
            return reply(.invalidInput, "Invalid or stale workload event.")
        } catch ControlError.invalid {
            return reply(.invalidInput, "Invalid task hook event.")
        } catch {
            return reply(resultCode, error.localizedDescription)
        }
    }

    private var resultCode: ControlCode {
        if controller.phase == .recovery || controller.phase == .unverified { return .unverified }
        if controller.helperState?.flag == .on, controller.helperState?.ownsOverride == false { return .conflict }
        if controller.requestedMode?.needsHelper == true, !closedLidReady { return .approvalRequired }
        return .blocked
    }

    private func notifyWorkload(_ message: String) {
        diagnostics.record(controller.phase, message)
        guard !isPreview, notify else { return }
        let content = UNMutableNotificationContent()
        content.title = "LidPilot task update"; content.body = message; content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }

    private func sessionChanged(_ phase: SessionPhase, _ message: String) {
        diagnostics.record(phase, message)
        onStatusChange?()
        scheduleHeartbeat()
        if !isPreview, notify, phase == .paused || phase == .recovery || (phase == .off && message == "Your session has ended.") {
            let content = UNMutableNotificationContent()
            content.title = phase == .recovery ? "Cleanup needs attention" : (phase == .paused ? "LidPilot paused" : "Session finished")
            content.body = message
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            let center = UNUserNotificationCenter.current()
            Task { [weak self] in
                do {
                    try await center.add(request)
                    let settings = await center.notificationSettings()
                    self?.diagnostics.record(phase, "macOS accepted a session notification; authorization status: \(settings.authorizationStatus.rawValue). Presentation remains subject to macOS notification settings.")
                } catch {
                    self?.diagnostics.record(phase, "Could not queue a session notification: \(error.localizedDescription)")
                }
            }
        }
    }

    private func scheduleHeartbeat() {
        guard controller.hasSession else {
            heartbeatGeneration += 1; heartbeat?.cancel(); heartbeat = nil; heartbeatDue = nil
            return
        }
        let delay = controller.nextCheckDelay
        let due = ProcessInfo.processInfo.systemUptime + delay
        // Busy hook traffic must never postpone a scheduled lease renewal.
        if heartbeat != nil, let heartbeatDue, heartbeatDue <= due { return }
        heartbeatGeneration += 1
        let token = heartbeatGeneration
        heartbeat?.cancel()
        heartbeatDue = due
        heartbeat = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self, !Task.isCancelled, token == self.heartbeatGeneration else { return }
            self.heartbeat = nil; self.heartbeatDue = nil
            #if LIDPILOT_PROFILE
            PerformanceTrace.event("heartbeat", fields: ["stage": "fire", "delay_s": String(delay), "phase": String(describing: self.controller.phase)])
            PerformanceTrace.event("reconcile_trigger", fields: ["source": "heartbeat", "phase": String(describing: self.controller.phase)])
            #endif
            await self.controller.reconcile()
            self.scheduleHeartbeat()
        }
    }
}
