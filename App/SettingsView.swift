import SwiftUI
import LidPilotCore
import LidPilotRuntime

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General", safety = "Safety", agents = "Agent Tasks", developer = "Command Line", shortcuts = "Shortcuts", helper = "Helper & Recovery", updates = "Updates", diagnostics = "Diagnostics"
    var id: Self { self }
    var icon: String {
        switch self { case .general: "slider.horizontal.3"; case .safety: "shield"; case .agents: "bolt.circle"; case .developer: "terminal"; case .shortcuts: "keyboard"; case .helper: "lock.shield"; case .updates: "arrow.triangle.2.circlepath"; case .diagnostics: "stethoscope" }
    }
    var detail: String {
        switch self {
        case .general: "Make room for the way you work."
        case .safety: "Your limits apply to every session and task."
        case .agents: "Connect once. Control it from your menu bar."
        case .developer: "Local commands. Clear task boundaries."
        case .shortcuts: "Your most useful actions, one keystroke away."
        case .helper: "Understand what LidPilot can confirm."
        case .updates: "Choose one way to keep LidPilot current."
        case .diagnostics: "A clear picture, kept on this Mac."
        }
    }
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var section: SettingsSection = .general
    @State private var showingExport = false
    @State private var removingHelper = false
    @State private var actionError: String?

    init(model: AppModel, initialSection: SettingsSection = .general) {
        self.model = model
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 9) { PilotMark(size: 28); Text("LidPilot").font(.system(size: 17, weight: .semibold)) }.padding(.bottom, 18)
                ForEach(SettingsSection.allCases) { item in
                    Button { section = item } label: {
                        Label(item.rawValue, systemImage: item.icon).font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10).padding(.horizontal, 10)
                            .background(section == item ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                if section == item && contrast == .increased {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.primary.opacity(0.75), lineWidth: 1.5)
                                }
                            }
                    }.buttonStyle(.plain).accessibilityAddTraits(section == item ? .isSelected : [])
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Label(model.controller.phase.title, systemImage: model.controller.hasSession ? "bolt.circle" : "power")
                        .font(.caption.weight(.medium))
                    Text("Always starts Off").font(.caption2).foregroundStyle(.secondary)
                }.padding(.horizontal, 10)
            }.padding(18).frame(width: 185).background(.regularMaterial)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(section.rawValue).font(.title2.weight(.semibold))
                    Text(section.detail).font(.subheadline).foregroundStyle(.secondary)
                }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 4)
                Form {
                    switch section {
                    case .general: general
                    case .safety: safety
                    case .agents: AgentTasksSettings(model: model)
                    case .developer: developer
                    case .shortcuts: Section("Global shortcuts") { ShortcutSettingsView(shortcuts: model.shortcuts) }
                    case .helper: helper
                    case .updates: updates
                    case .diagnostics: diagnostics
                    }
                }.formStyle(.grouped).scrollContentBackground(.hidden)
            }.frame(width: 520)
        }
        .frame(height: 590)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if model.controller.phase == .recovery { section = .helper }
            Task { await model.controller.refreshWhileOff() }
            model.refreshHookSetup()
        }
        .alert("Restore normal sleep policy?", isPresented: $model.showRecoveryConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore Sleep Policy", role: .destructive) { Task { await model.controller.recoverAfterConfirmation() } }
        } message: {
            Text("This changes the system-wide sleep override. Quit any other closed-lid controller first. Open the lid and save your work; the Mac may sleep afterward.")
        }
        .alert("Remove the helper?", isPresented: $removingHelper) {
            Button("Cancel", role: .cancel) {}
            Button("Remove Helper", role: .destructive) {
                Task {
                    await model.controller.stop()
                    guard model.controller.phase == .off else { return }
                    do { try await model.helper.unregister(); model.refreshHelper() }
                    catch { actionError = error.localizedDescription }
                }
            }
        } message: { Text("LidPilot will verify that its controls are off before removing its helper registration.") }
        .sheet(isPresented: $showingExport) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Review before exporting").font(.title2.weight(.semibold))
                Text("This local report contains power status and recent LidPilot events. Review its contents before sharing.").foregroundStyle(.secondary)
                ScrollView { Text(model.exportPreview).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    .padding(12).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                HStack { Button("Cancel") { showingExport = false }; Spacer(); Button("Save Report…") { model.exportDiagnostics(); showingExport = false }.buttonStyle(.borderedProminent) }
            }.padding(24).frame(width: 550, height: 430)
        }
    }

    /// Include labels in the spoken text even when macOS groups adjacent rows.
    private func statusRow(_ title: String, value: String) -> some View {
        LabeledContent(title, value: value)
            .accessibilityRepresentation { Text("\(title): \(value)") }
    }

    private var general: some View {
        Group {
            Section("Defaults") {
                Picker("Preferred behavior", selection: $model.selectedMode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.title).tag($0) }
                }.disabled(model.controller.hasSession)
                Picker("Session duration", selection: $model.duration) {
                    ForEach(DurationChoice.allCases) { Text($0.title).tag($0) }
                }.disabled(model.controller.hasSession)
                Text("Choosing a preference never starts a session.").font(.caption).foregroundStyle(.secondary)
            }
            Section("At your convenience") {
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLogin($0) }))
                Toggle("Session & safety notifications", isOn: Binding(get: { model.notify }, set: { enabled in
                    if enabled { model.requestNotifications() } else { model.notify = false }
                }))
                Text("Login and updates always open LidPilot Off.").font(.caption).foregroundStyle(.secondary)
                if let error = model.loginError { Text(error).font(.caption).foregroundStyle(.orange) }
            }
        }
    }
    private var safety: some View {
        Group {
            Section("Battery") {
                Picker("Pause at", selection: $model.batteryFloor) {
                    ForEach([10, 20, 30], id: \.self) { Text("\($0)% remaining").tag($0) }
                }
                Toggle("Allow closed-lid sessions on battery", isOn: $model.allowBattery)
                Toggle("Respect Low Power Mode", isOn: $model.respectLowPower)
                Text("Applies to Follow Lid and Keep Mac Running. By default, unplugging pauses the session.").font(.caption).foregroundStyle(.secondary)
            }.disabled(model.controller.hasSession)
            Section("Thermal protection") {
                statusRow("Thermal protection", value: "Always on")
                Text("Serious or critical thermal pressure ends the session. Safety pauses require an explicit restart.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("Turn Off before changing safety settings. Keep a running Mac on a ventilated surface; LidPilot cannot detect a bag or guarantee physical safety.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var developer: some View {
        Group {
            Section("Command line") {
                Toggle("Allow local CLI control", isOn: $model.cliEnabled)
                    .disabled(model.controller.hasSession || model.controller.updateBarrier)
                Text("Lets scripts running as your Mac user ask this app to start, stop, and report status. Every action uses the same safety checks.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Install CLI in a Folder…") { model.installCLI() }
                Text("Creates a lidpilot link in a folder you choose. Existing files and shell settings are preserved.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("For Codex and Claude Code, use Agent Tasks. You do not need to install a shell command for that connection.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open Agent Tasks") { section = .agents }
                if let error = model.controlError { Text(error).font(.caption).foregroundStyle(.orange) }
            }
        }
    }
    private var helper: some View {
        Group {
            Section("Closed-lid support") {
                statusRow("Helper", value: model.helper.label)
                Text("A small privileged helper controls one macOS sleep setting. It is only required for Follow Lid and Keep Mac Running.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(model.helper.status == .requiresApproval ? "Open System Settings" : "Enable Helper") {
                        if model.helper.status == .requiresApproval { model.helper.openApproval() } else { model.approveHelper() }
                    }.disabled(!model.helper.signed || model.helper.enabled || model.controller.hasSession)
                    Button("Refresh") { model.refreshHelper(); Task { await model.controller.refreshWhileOff() } }
                }
                if let error = model.helper.error { Text(error).font(.caption).foregroundStyle(.orange) }
            }
            Section("Verified status") {
                statusRow("Session", value: model.controller.phase.title)
                statusRow("System sleep override", value: model.controller.helperState?.flag.rawValue ?? "unknown")
                statusRow("Internal panel power", value: "Not measured")
                Text(model.controller.message).font(.caption).foregroundStyle(.secondary)
            }
            Section("Recovery") {
                Button("Retry LidPilot Cleanup") { Task { await model.controller.stop() } }
                    .disabled(model.controller.hasSession || model.controller.updateBarrier)
                Button("Restore Normal Sleep Policy…") { model.showRecoveryConfirmation = true }
                    .disabled(!model.helper.enabled || model.controller.hasSession || model.controller.updateBarrier)
                Button("Remove Helper…") { removingHelper = true }.disabled(!model.helper.signed || model.controller.updateBarrier)
                Button("Repair Helper Registration") {
                    Task {
                        await model.controller.refreshWhileOff()
                        await model.controller.stop()
                        guard model.controller.phase == .off else { return }
                        do {
                            try await model.helper.unregister()
                            model.approveHelper()
                            await model.controller.refreshWhileOff()
                        } catch { actionError = error.localizedDescription }
                    }
                }.disabled(!model.helper.signed || model.controller.hasSession || model.controller.updateBarrier)
                if let actionError { Text(actionError).font(.caption).foregroundStyle(.orange) }
            }
        }
    }
    private var updates: some View {
        Group {
            Section("Update method") {
                Picker("Managed by", selection: Binding(get: { model.updateOwnership.method }, set: {
                    model.updateOwnership.select($0)
                    _ = model.updater?.refreshUpdateOwnership()
                })) {
                    ForEach(UpdateMethod.allCases) { Text($0.title).tag($0) }
                }.disabled(model.updater?.isBusy == true || model.controller.updateBarrier)
                Text(model.updateOwnership.selectionDescription + ". You can choose a method if detection is incorrect.")
                    .font(.caption).foregroundStyle(.secondary)
                if model.updateOwnership.method == .homebrew {
                    Text("Turn Off before running brew upgrade --cask lidpilot. Homebrew owns replacement; Sparkle is disabled.")
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                } else if model.updateOwnership.method == .manual {
                    Link("Download a signed release", destination: URL(string: "https://lidpilot.app")!)
                }
            }
            Section("In-app updates") {
                if let updater = model.updater {
                    Text(updater.status).font(.subheadline).foregroundStyle(.secondary)
                    Toggle("Check for updates automatically", isOn: Binding(get: { updater.automaticChecks }, set: { updater.automaticChecks = $0 }))
                        .disabled(!updater.configured || model.updateOwnership.method != .sparkle)
                    Button("Check for Updates…") { updater.check() }
                        .disabled(!updater.canCheck || model.controller.hasSession)
                }
            }
            Section {
                Text("In-app checks run approximately daily when enabled. No analytics or system profiling. Installation is manual and requires LidPilot Off, an open lid, and verified helper cleanup.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var diagnostics: some View {
        Group {
            Section("Troubleshooting") {
                Text(model.controller.lastConfirmedOperation ?? "No operation confirmed this launch.").font(.subheadline)
                Text(ControlStatus(controller: model.controller).nextStep).font(.caption).foregroundStyle(.secondary)
                if let date = model.controller.observation?.sampledAt.wallDate {
                    statusRow("Last observation", value: date.formatted(date: .omitted, time: .standard))
                }
            }
            Section("Local status") {
                statusRow("Power", value: model.controller.observation?.power.rawValue ?? "unknown")
                statusRow("Lid", value: model.controller.observation?.lid.rawValue ?? "unknown")
                statusRow("Thermal pressure", value: model.controller.observation?.thermal.rawValue ?? "unknown")
                statusRow("System assertion", value: model.controller.assertions.system.rawValue)
                statusRow("Display assertion", value: model.controller.assertions.display.rawValue)
            }
            Section("Diagnostics") {
                Text("Local events are kept for up to 7 days, below 5 MB. Reports include task state and opaque identifiers, never command arguments or agent content. Nothing is uploaded.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Copy Status") { model.copyStatus() }
                    Button("Preview Export…") {
                        model.exportPreview = model.diagnosticReport()
                        showingExport = true
                    }
                    Button("Clear Events") { model.diagnostics.clear() }
                }
                if let error = model.diagnostics.storageError { Text(error).font(.caption).foregroundStyle(.orange) }
            }
        }
    }
}
