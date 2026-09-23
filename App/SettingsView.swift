import SwiftUI
import LidPilotCore
import LidPilotRuntime

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General", safety = "Safety", helper = "Helper & Recovery", updates = "Updates", diagnostics = "Diagnostics"
    var id: Self { self }
    var icon: String {
        switch self { case .general: "slider.horizontal.3"; case .safety: "shield"; case .helper: "lock.shield"; case .updates: "arrow.triangle.2.circlepath"; case .diagnostics: "stethoscope" }
    }
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var section: SettingsSection = .general
    @State private var showingExport = false
    @State private var removingHelper = false
    @State private var actionError: String?

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
                Label("Always starts Off", systemImage: "power").font(.caption).foregroundStyle(.secondary)
            }.padding(18).frame(width: 185).background(.regularMaterial)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Text(section.rawValue).font(.title2.weight(.semibold)).padding(.horizontal, 24).padding(.top, 24)
                Form {
                    switch section {
                    case .general: general
                    case .safety: safety
                    case .helper: helper
                    case .updates: updates
                    case .diagnostics: diagnostics
                    }
                }.formStyle(.grouped).scrollContentBackground(.hidden)
            }.frame(width: 465)
        }
        .frame(height: 530)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if model.controller.phase == .recovery || (model.selectedMode.needsHelper && !model.helper.enabled) { section = .helper }
            Task { await model.controller.refreshWhileOff() }
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
            Section("LidPilot 1.0") {
                if let updater = model.updater {
                    Text(updater.status).font(.subheadline).foregroundStyle(.secondary)
                    Toggle("Check for updates automatically", isOn: Binding(get: { updater.automaticChecks }, set: { updater.automaticChecks = $0 }))
                        .disabled(!updater.configured)
                    Button("Check for Updates…") { updater.check() }
                        .disabled(!updater.canCheck || model.controller.hasSession)
                }
            }
            Section {
                Text("Checks run approximately daily through GitHub. No analytics or system profiling. Installation is manual and requires LidPilot Off, an open lid, and verified helper cleanup.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var diagnostics: some View {
        Group {
            Section("Local status") {
                statusRow("Power", value: model.controller.observation?.power.rawValue ?? "unknown")
                statusRow("Lid", value: model.controller.observation?.lid.rawValue ?? "unknown")
                statusRow("Thermal pressure", value: model.controller.observation?.thermal.rawValue ?? "unknown")
                statusRow("System assertion", value: model.controller.assertions.system.rawValue)
                statusRow("Display assertion", value: model.controller.assertions.display.rawValue)
            }
            Section("Diagnostics") {
                Text("Stored on this Mac for up to 7 days, below 5 MB. No workload data, account, or analytics.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Preview Export…") {
                        model.exportPreview = model.diagnostics.report(controller: model.controller, helper: model.helper)
                        showingExport = true
                    }
                    Button("Clear Events") { model.diagnostics.clear() }
                }
                if let error = model.diagnostics.storageError { Text(error).font(.caption).foregroundStyle(.orange) }
            }
        }
    }
}
