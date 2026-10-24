import SwiftUI
import LidPilotCore
import LidPilotRuntime

struct PilotPanel: View {
    @Bindable var model: AppModel
    #if DEBUG
    // Product captures stage real UI without the QA-only banner. Interactive
    // preview windows keep the notice; simulated power controls stay isolated.
    var showsPreviewNotice = true
    #endif
    var onSettings: (() -> Void)?
    var onWelcome: (() -> Void)?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                PilotMark(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("LidPilot").font(.system(size: 18, weight: .semibold))
                    Text("A clear way to stay awake.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(model.controller.integrationsArmed && !model.controller.hasSession ? Color.accentColor : model.controller.phase.color).frame(width: 6, height: 6)
                    Text(model.menuBarStatus).font(.caption.weight(.medium))
                }
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(Color.primary.opacity(0.05), in: Capsule())
                .accessibilityElement(children: .combine)
            }

            #if DEBUG
            if model.isPreview && showsPreviewNotice {
                Label("Preview · power controls are simulated", systemImage: "testtube.2")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            #endif

            VStack(spacing: 7) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    modeCard(mode)
                }
            }
            .disabled(model.controller.updateBarrier || model.controller.phase == .stopping)

            VStack(alignment: .leading, spacing: 5) {
                Toggle(isOn: Binding(get: { model.keepsDesktopAvailable }, set: { model.setKeepsDesktopAvailable($0) })) {
                    Label("Prevent automatic lock", systemImage: model.keepsDesktopAvailable ? "lock.open" : "lock")
                        .font(.subheadline.weight(.medium))
                }
                .toggleStyle(.switch).controlSize(.small)
                .disabled(model.controller.hasSession || model.controller.integrationsArmed || model.controller.updateBarrier || model.controller.phase == .stopping)
                .accessibilityLabel("Prevent automatic screen lock during sessions")
                .accessibilityHint("Choose before starting. Off allows normal locking with the lid closed. Manual Lock remains available.")
                Text(model.keepsDesktopAvailable
                     ? "For computer use · display may stay on."
                     : "Allow normal locking with the lid closed.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.controller.hasSession || model.controller.integrationsArmed {
                    Text("Turn Off before changing this choice.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let error = model.desktopAvailabilityError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SESSION LENGTH").font(.caption2.weight(.semibold)).tracking(0.7).foregroundStyle(.secondary)
                        if model.controller.manualMode != nil {
                            Text(model.controller.manualRemaining == nil ? "Protection stays on until you turn it off" : "Protection ends when this timer runs out")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if model.controller.manualMode != nil, model.controller.manualRemaining != nil {
                        if visible {
                            TimelineView(.periodic(from: .now, by: 1)) { _ in
                                #if LIDPILOT_PROFILE
                                let _ = PerformanceTrace.event("ui_timeline_render", fields: ["visible": String(visible)])
                                #endif
                                Text(remainingText).font(.subheadline.weight(.medium).monospacedDigit()).foregroundStyle(.primary)
                            }
                        } else {
                            #if LIDPILOT_PROFILE
                            let _ = PerformanceTrace.event("ui_timeline_render", fields: ["visible": String(visible)])
                            #endif
                            Text(remainingText).font(.subheadline.weight(.medium).monospacedDigit()).foregroundStyle(.primary)
                        }
                    } else if model.controller.manualMode != nil {
                        Text("Until you stop").font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    } else {
                        Text(durationSummary).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    }
                }
                HStack(spacing: 5) {
                    ForEach([DurationChoice.halfHour, .hour, .twoHours]) { choice in
                        Button {
                            model.duration = choice
                        } label: {
                            Text(shortTitle(choice)).font(.caption.weight(.medium))
                                .frame(maxWidth: .infinity).padding(.vertical, 7)
                                .background(model.duration == choice ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(model.duration == choice ? Color.accentColor.opacity(contrast == .increased ? 1 : 0.6) : .clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(choice.title)
                        .accessibilityAddTraits(model.duration == choice ? .isSelected : [])
                    }
                    Button { model.duration = .indefinite } label: {
                        Text("Until I stop")
                            .font(.caption.weight(.medium))
                            .frame(minWidth: 74, minHeight: 28)
                            .background(model.duration == .indefinite ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(model.duration == .indefinite ? Color.accentColor.opacity(contrast == .increased ? 1 : 0.6) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Until I stop")
                    .accessibilityAddTraits(model.duration == .indefinite ? .isSelected : [])
                    Menu {
                        ForEach([DurationChoice.fourHours, .custom, .until]) { choice in
                            Button {
                                model.duration = choice
                            } label: {
                                if model.duration == choice {
                                    Label(choice.title, systemImage: "checkmark")
                                } else {
                                    Text(choice.title)
                                }
                            }
                        }
                    } label: { Text("More").font(.caption.weight(.medium)).frame(minWidth: 43, minHeight: 28) }
                        .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("More session durations: four hours, custom, or until a time")
                }
                .disabled(model.controller.manualMode != nil)
                if model.controller.manualMode == nil, model.duration == .custom {
                    HStack {
                        Text("Minutes").foregroundStyle(.secondary)
                        TextField("Minutes", value: $model.customMinutes, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 90)
                        Stepper("Minutes", value: $model.customMinutes, in: 1...10_080).labelsHidden()
                    }.font(.subheadline)
                }
                if model.controller.manualMode == nil, model.duration == .until {
                    DatePicker("End at", selection: $model.untilDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.field).font(.subheadline)
                }
                if model.controller.manualMode == nil, model.duration == .indefinite {
                    Text("This session stays on until you turn it off.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if model.controller.hasSession || model.controller.integrationsArmed, model.controller.manualMode == nil {
                    Button("Add a manual session") { model.start() }
                        .font(.subheadline).disabled(model.controller.updateBarrier)
                }
            }

            if model.showAgentControls || model.controller.integrationsArmed {
                VStack(alignment: .leading, spacing: 9) {
                    AgentTaskControl(model: model)
                    WorkloadActivityView(model: model)
                    HStack {
                        Text(agentConnections).font(.system(size: 10)).foregroundStyle(.secondary)
                        Spacer(minLength: 6)
                        Button(model.hookInstallations.values.contains(.installed) || !model.lastHookReceived.isEmpty ? "Manage…" : "Set Up…") { model.openAgentSettings?() }
                            .font(.system(size: 11)).buttonStyle(.link)
                            .accessibilityLabel("Set up and manage agent tasks")
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
            }
            if model.controller.workloads.records.contains(where: { $0.source == .command }) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("COMMAND TASKS", systemImage: "terminal").font(.system(size: 10, weight: .semibold))
                    WorkloadActivityView(model: model, agents: false)
                }.padding(12).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: statusSymbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(model.controller.phase.color)
                    .frame(width: 16).padding(.top, 2).accessibilityHidden(true)
                Text(model.controller.message).font(.caption).foregroundStyle(.secondary)
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)

            VStack(spacing: 10) {
                Button {
                    if model.controller.hasSession || model.controller.integrationsArmed { Task { await model.controller.stop() } }
                    else if model.controller.phase == .recovery { showSettings() }
                    else if needsHelperSetup { showSettings() }
                    else { model.start() }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: model.controller.hasSession || model.controller.integrationsArmed ? "stop.fill" : primarySymbol).font(.system(size: 10, weight: .semibold))
                        Text(primaryTitle).font(.body.weight(.semibold))
                    }.frame(maxWidth: .infinity).padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(model.controller.phase == .stopping || model.controller.updateBarrier)

                HStack {
                    Button { Task { await model.controller.stopAndSleep() } } label: {
                        Label("Stop & Sleep", systemImage: "moon.zzz")
                    }.disabled(model.controller.updateBarrier)
                    Spacer()
                    if let battery = model.controller.observation?.batteryPercent {
                        Label("\(battery)%", systemImage: model.controller.observation?.power == .external ? "bolt.fill" : "battery.100percent")
                            .font(.system(size: 10)).accessibilityLabel("Battery \(battery) percent")
                    }
                    Divider().frame(height: 12).padding(.horizontal, 2)
                    Button { showSettings() } label: { Image(systemName: "gearshape").frame(width: 20, height: 22) }
                        .accessibilityLabel("Open Settings").help("Settings")
                    Menu {
                        Button("Copy Status") { model.copyStatus() }
                        Button("Check for Updates…") { model.updater?.check() }
                            .disabled(model.updater?.canCheck != true || model.controller.hasSession)
                        Button("Welcome & Help") { showWelcome() }
                        Divider()
                        Button("Quit LidPilot") { NSApp.terminate(nil) }.keyboardShortcut("q")
                    } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize()
                        .accessibilityLabel("More LidPilot actions")
                }.font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(20).frame(width: 370)
        .background {
            if reduceTransparency { Color(nsColor: .windowBackgroundColor) }
            else {
                Rectangle().fill(.regularMaterial)
                    .overlay(Color(nsColor: .windowBackgroundColor).opacity(0.45))
            }
        }
        .onAppear {
            visible = true
            model.refreshHookSetup()
            if !model.onboardingComplete && !model.isPreview { model.showOnboarding = true }
        }
        .onDisappear { visible = false }
        .onChange(of: model.showOnboarding) { _, value in
            if value { showWelcome(); model.showOnboarding = false }
        }
    }

    private func modeCard(_ mode: Mode) -> some View {
        let selected = model.selectedMode == mode
        let active = model.controller.phase == .active && model.controller.effectiveMode == mode
        return Button { model.chooseMode(mode) } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.symbol).font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .frame(width: 34, height: 34)
                    .background(selected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(mode.title).font(.subheadline.weight(.medium))
                        if active {
                            Text("ACTIVE")
                                .font(.caption2.weight(.bold))
                                .tracking(0.35)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.1), in: Capsule())
                        }
                    }
                    Text(mode.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15)).foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.5))
            }
            .padding(.horizontal, 11).padding(.vertical, 9).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.045) : Color(nsColor: .controlBackgroundColor).opacity(0.82), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.accentColor.opacity(contrast == .increased ? 1 : 0.65) : Color.primary.opacity(contrast == .increased ? 0.45 : 0.08), lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.title)\(selected ? ", selected" : "")\(active ? ", active mode" : "")")
        .accessibilityHint(mode.detail + (mode.needsHelper ? ". macOS may still lock. Desktop automation may need you to unlock it." : ""))
        .help(mode.needsHelper ? (model.keepsDesktopAvailable
            ? "Idle display sleep is inhibited during sessions. The display may stay on; manual Lock still works."
            : "macOS may still lock. Desktop automation may need you to unlock it.") : mode.detail)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var statusSymbol: String {
        switch model.controller.phase {
        case .active: "checkmark.shield"
        case .paused, .unverified, .recovery: "exclamationmark.triangle"
        case .starting, .stopping, .updating: "arrow.triangle.2.circlepath"
        case .off: "power"
        }
    }
    private var agentConnections: String {
        let connected = AppModel.agentSources.filter { model.hookInstallations[$0] == .installed }
        if !connected.isEmpty { return "Hooks: " + connected.map(\.agentTitle).joined(separator: " · ") }
        let received = AppModel.agentSources.filter { model.lastHookReceived[$0] != nil }
        if !received.isEmpty { return received.map(\.agentTitle).joined(separator: " · ") + " · events received" }
        return model.hookSetupErrors.isEmpty ? "No connection set up" : "Setup needs attention"
    }
    private var primarySymbol: String {
        model.controller.phase == .recovery ? "arrow.clockwise" :
            (needsHelperSetup ? "lock.shield" : "play.fill")
    }
    private var needsHelperSetup: Bool {
        model.selectedMode.needsHelper && (!model.closedLidReady || model.controller.phase == .unverified)
    }
    private var primaryTitle: String {
        if model.controller.integrationsArmed { return "Turn Off All Requests" }
        if model.controller.hasSession { return model.controller.workloads.records.isEmpty ? "Turn Off" : "Turn Off All Requests" }
        if model.controller.phase == .recovery { return "Open Recovery" }
        if needsHelperSetup { return model.controller.phase == .unverified ? "Check Helper Status" : "Set Up Closed-Lid Support" }
        return "Start Session"
    }
    private var remainingText: String {
        guard let seconds = model.controller.manualRemaining else { return "Until you stop" }
        let value = max(0, Int(seconds.rounded(.up)))
        let countdown = value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60) : String(format: "%d:%02d", value / 60, value % 60)
        return "Ends in \(countdown)"
    }
    private var durationSummary: String {
        switch model.duration {
        case .halfHour: "30 min"
        case .hour: "1 hour"
        case .twoHours: "2 hours"
        case .fourHours: "4 hours"
        case .custom: "\(model.customMinutes) min"
        case .until: model.untilDate.formatted(date: .abbreviated, time: .shortened)
        case .indefinite: "Until I stop"
        }
    }
    private func shortTitle(_ choice: DurationChoice) -> String {
        switch choice { case .halfHour: "30m"; case .hour: "1h"; case .twoHours: "2h"; default: "4h" }
    }
    private func showSettings() {
        if let onSettings { onSettings() } else { openWindow(id: "settings"); NSApp.activate(ignoringOtherApps: true) }
    }
    private func showWelcome() {
        if let onWelcome { onWelcome() } else { openWindow(id: "welcome"); NSApp.activate(ignoringOtherApps: true) }
    }
}

/// The same light/dark LP artwork used by the native application icon.
struct PilotMark: View {
    var size: CGFloat = 40
    var body: some View {
        Image("PilotIcon")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
