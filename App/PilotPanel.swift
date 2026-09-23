import SwiftUI
import LidPilotCore
import LidPilotRuntime

struct PilotPanel: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                PilotMark(size: 32)
                Text("LidPilot").font(.system(size: 18, weight: .semibold))
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(model.controller.phase.color).frame(width: 5, height: 5)
                    Text(model.controller.phase.title).font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Color.primary.opacity(0.045), in: Capsule())
                .accessibilityElement(children: .combine)
            }
            .padding(.bottom, 2)

            if model.isPreview {
                Label("Preview · power controls are simulated", systemImage: "testtube.2")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    modeCard(mode)
                }
            }
            .disabled(model.controller.updateBarrier || model.controller.phase == .stopping)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SESSION").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                    Spacer()
                    if model.controller.hasSession {
                        TimelineView(.animation(minimumInterval: 1, paused: !visible)) { _ in
                            Text(remainingText).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(model.duration.title).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    ForEach([DurationChoice.halfHour, .hour, .twoHours, .fourHours]) { choice in
                        Button {
                            model.duration = choice
                        } label: {
                            Text(shortTitle(choice)).font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity).padding(.vertical, 7)
                                .background(model.duration == choice ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(model.duration == choice ? Color.accentColor.opacity(0.65) : .clear))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(choice.title)
                        .accessibilityAddTraits(model.duration == choice ? .isSelected : [])
                    }
                    Menu {
                        ForEach([DurationChoice.custom, .until, .indefinite]) { choice in
                            Button(choice.title) { model.duration = choice }
                        }
                    } label: { Image(systemName: "ellipsis").frame(width: 22, height: 27) }
                        .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("More session durations")
                }
                .disabled(model.controller.hasSession)
                if !model.controller.hasSession, model.duration == .custom {
                    HStack {
                        Text("Minutes").foregroundStyle(.secondary)
                        TextField("Minutes", value: $model.customMinutes, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 90)
                        Stepper("Minutes", value: $model.customMinutes, in: 1...10_080).labelsHidden()
                    }.font(.subheadline)
                }
                if !model.controller.hasSession, model.duration == .until {
                    DatePicker("End at", selection: $model.untilDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.field).font(.subheadline)
                }
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: statusSymbol).font(.system(size: 12)).foregroundStyle(model.controller.phase.color)
                    .frame(width: 16).padding(.top, 2).accessibilityHidden(true)
                Text(model.controller.message).font(.system(size: 11)).foregroundStyle(.secondary)
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)

            VStack(spacing: 10) {
                Button {
                    if model.controller.hasSession { Task { await model.controller.stop() } }
                    else if model.controller.phase == .recovery { showSettings() }
                    else if needsHelperSetup { showSettings() }
                    else { model.start() }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: model.controller.hasSession ? "stop.fill" : primarySymbol).font(.system(size: 10, weight: .semibold))
                        Text(primaryTitle).font(.system(size: 13, weight: .semibold))
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
                        Button("Check for Updates…") { model.updater?.check() }
                            .disabled(model.updater?.canCheck != true || model.controller.hasSession)
                        Button("Welcome & Help") { openWindow(id: "welcome"); NSApp.activate(ignoringOtherApps: true) }
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
            if !model.onboardingComplete && !model.isPreview { model.showOnboarding = true }
        }
        .onDisappear { visible = false }
        .onChange(of: model.showOnboarding) { _, value in
            if value { openWindow(id: "welcome"); model.showOnboarding = false; NSApp.activate(ignoringOtherApps: true) }
        }
    }

    private func modeCard(_ mode: Mode) -> some View {
        let selected = model.selectedMode == mode
        return Button { model.chooseMode(mode) } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.symbol).font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .frame(width: 34, height: 34)
                    .background(selected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title).font(.system(size: 13, weight: .medium))
                    Text(mode.detail).font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14)).foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.5))
            }
            .padding(.horizontal, 12).padding(.vertical, 11).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.045) : Color(nsColor: .controlBackgroundColor).opacity(0.82), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(contrast == .increased ? 0.45 : 0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title).accessibilityHint(mode.detail)
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
    private var primarySymbol: String {
        model.controller.phase == .recovery ? "arrow.clockwise" :
            (needsHelperSetup ? "lock.shield" : "play.fill")
    }
    private var needsHelperSetup: Bool {
        model.selectedMode.needsHelper && (!model.closedLidReady || model.controller.phase == .unverified)
    }
    private var primaryTitle: String {
        if model.controller.hasSession { return "Turn Off" }
        if model.controller.phase == .recovery { return "Open Recovery" }
        if needsHelperSetup { return model.controller.phase == .unverified ? "Check Helper Status" : "Set Up Closed-Lid Support" }
        return "Start Session"
    }
    private var remainingText: String {
        guard let seconds = model.controller.remaining else { return "Until you stop" }
        let value = max(0, Int(seconds.rounded(.up)))
        return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60) : String(format: "%d:%02d", value / 60, value % 60)
    }
    private func shortTitle(_ choice: DurationChoice) -> String {
        switch choice { case .halfHour: "30m"; case .hour: "1h"; case .twoHours: "2h"; default: "4h" }
    }
    private func showSettings() { openWindow(id: "settings"); NSApp.activate(ignoringOtherApps: true) }
}

/// A quiet system-symbol mark, shared by the menu, welcome screen, and settings.
struct PilotMark: View {
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: "laptopcomputer.and.arrow.down")
            .font(.system(size: size * 0.52, weight: .medium))
            .foregroundStyle(.tint)
            .frame(width: size, height: size)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: size * 0.27))
            .overlay(RoundedRectangle(cornerRadius: size * 0.27).strokeBorder(Color.accentColor.opacity(0.12)))
            .accessibilityHidden(true)
    }
}
