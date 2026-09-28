#if DEBUG
import Foundation
import SwiftUI
import AppKit
import LidPilotCore
import LidPilotRuntime

/// Native UI QA fixture. Compiled out of Release; no IOKit writes, XPC, helper registration, or pmset.
final class PreviewMachine: RuntimeClock, PowerSampling, SleepFlagControlling, RecoveryStoring, @unchecked Sendable {
    private let clock = SystemClock()
    private var flag: FlagState = .off
    private var record: RecoveryRecord?
    func now() -> ClockSample { clock.now() }
    func sample(flag: FlagState) -> PowerSnapshot {
        PowerSnapshot(sampledAt: now(), lid: .open, power: .external, batteryPercent: 82,
                      thermal: .nominal, lowPowerMode: false, externalDisplayCount: 0, sleepDisabled: flag)
    }
    func read() throws -> FlagState { flag }
    func setDisabled(_ disabled: Bool) throws { flag = disabled ? .on : .off }
    func load() throws -> RecoveryRecord? { record }
    func save(_ record: RecoveryRecord) throws { self.record = record }
    func clear() throws { record = nil }
}

@MainActor final class PreviewAssertions: PowerAssertions {
    private var state = AssertionState.off
    func apply(system: Bool, display: Bool, timeout: Double, displayTimeout: Double) throws -> AssertionState {
        state = AssertionState(system: system ? .on : .off, display: display ? .on : .off)
        return state
    }
    func release() throws -> AssertionState { state = .off; return state }
    func observed() -> AssertionState { state }
    func sleep() throws {}
}

@MainActor final class PreviewTransport: HelperTransport {
    private let engine: HelperEngine
    private let id = UUID()
    init(machine: PreviewMachine) {
        engine = HelperEngine(driver: machine, sampler: machine, journal: machine, clock: machine, build: "preview")
    }
    func send(_ request: WireRequest) async throws -> WireReply { engine.handle(request, client: id) }
    func disconnect() { engine.disconnected(client: id) }
}
/// Renders only this app's mock views to image artifacts; never captures the desktop.
@MainActor func renderPreviewSnapshots(model: AppModel, directory: String) async throws {
    let folder = URL(fileURLWithPath: directory, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    func render<V: View>(_ view: V, name: String, width: CGFloat, scheme: ColorScheme = .light) throws {
        // Render our own AppKit-backed view so native menus and Forms are not
        // replaced by ImageRenderer's unsupported-control placeholders.
        let host = NSHostingView(rootView: view
            .environment(\.colorScheme, scheme)
            .background(scheme == .dark ? Color(nsColor: .windowBackgroundColor) : .white))
        host.setFrameSize(NSSize(width: width, height: 1))
        let height = max(1, host.fittingSize.height)
        let bounds = NSRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(contentRect: bounds, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = host
        host.frame = bounds
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw RuntimeFailure.unavailable("The native preview could not be rendered.")
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw RuntimeFailure.unavailable("The native preview could not be encoded.")
        }
        try data.write(to: folder.appendingPathComponent(name + ".png"), options: .atomic)
    }
    model.onboardingComplete = true
    model.cliEnabled = false
    model.showAgentControls = true
    model.selectedMode = .smart
    model.duration = .hour
    await model.controller.refreshWhileOff()
    try render(PilotPanel(model: model), name: "panel-off-light", width: 370)
    try render(PilotPanel(model: model), name: "panel-off-dark", width: 370, scheme: .dark)
    try render(PilotPanel(model: model, showsPreviewNotice: false), name: "product-off", width: 370)
    await model.controller.start(mode: .smart, duration: .seconds(3600), policy: model.policy)
    guard model.controller.phase == .active, model.controller.effectiveMode == .smart else {
        throw RuntimeFailure.unavailable("Mock session activation failed.")
    }
    try render(PilotPanel(model: model), name: "panel-active", width: 370)
    try render(PilotPanel(model: model, showsPreviewNotice: false), name: "product-follow-lid", width: 370)
    await model.controller.stop()
    guard model.controller.phase == .off, model.controller.assertions == .off else {
        throw RuntimeFailure.unavailable("Mock cleanup failed.")
    }
    // QA artifacts retain their banner; separate product captures stage the
    // same supported UI without QA chrome. Neither is hardware evidence.
    for (mode, name) in [(Mode.display, "keep-screen-on"), (.closed, "keep-mac-running")] {
        model.selectedMode = mode
        await model.controller.start(mode: mode, duration: .seconds(3600), policy: model.policy)
        guard model.controller.phase == .active, model.controller.effectiveMode == mode else {
            throw RuntimeFailure.unavailable("Product preview activation failed.")
        }
        try render(PilotPanel(model: model), name: name, width: 370)
        try render(PilotPanel(model: model, showsPreviewNotice: false), name: "product-" + name, width: 370)
        await model.controller.stop()
        guard model.controller.phase == .off, model.controller.assertions == .off else {
            throw RuntimeFailure.unavailable("Product preview cleanup failed.")
        }
    }
    model.cliEnabled = true
    model.hookInstallations[.codex] = .installed
    model.armTasks(true)
    guard model.controller.integrationsArmed, model.controller.protectedWorkloads.isEmpty else {
        throw RuntimeFailure.unavailable("Agent monitoring was not enabled independently of protection.")
    }
    try render(PilotPanel(model: model), name: "panel-agent-ready", width: 370)
    model.showAgentControls = false
    try render(PilotPanel(model: model), name: "panel-agent-visible-while-on", width: 370)
    model.showAgentControls = true
    model.selectedMode = .display
    await model.controller.start(mode: .display, duration: .seconds(3600), policy: model.policy)
    try model.controller.armWorkloads()
    let task = WorkloadEvent(eventID: UUID().uuidString, source: .codex, adapterVersion: "0.154.0",
        sessionID: "preview", turnID: "turn", sequence: 1, timestamp: Date(), state: .working, exitCode: nil)
    try await model.controller.handleWorkload(task, mode: .closed, policy: model.policy, options: model.workloadOptions)
    model.lastHookReceived[.codex] = Date()
    try render(PilotPanel(model: model), name: "panel-tasks-light", width: 370)
    try render(PilotPanel(model: model), name: "panel-tasks-dark", width: 370, scheme: .dark)
    model.armTasks(false)
    for _ in 0..<200 where model.changingAgentTasks { try await Task.sleep(for: .milliseconds(5)) }
    guard !model.controller.integrationsArmed, model.controller.manualMode == .display,
          model.controller.workloads.records.isEmpty else {
        throw RuntimeFailure.unavailable("The agent switch must preserve the manual session.")
    }
    model.armTasks(true)
    model.cliEnabled = false
    for _ in 0..<200 where model.changingAgentTasks { try await Task.sleep(for: .milliseconds(5)) }
    guard !model.controller.integrationsArmed else {
        throw RuntimeFailure.unavailable("Disabling the connection must also turn off agent monitoring.")
    }
    await model.controller.stop()
    model.showAgentControls = false
    try render(PilotPanel(model: model), name: "panel-agent-hidden", width: 370)
    model.showAgentControls = true
    model.cliEnabled = true
    try render(SettingsView(model: model), name: "settings", width: 706)
    for section in [SettingsSection.agents, .developer, .shortcuts, .updates, .diagnostics] {
        try render(SettingsView(model: model, initialSection: section), name: "settings-" + String(describing: section), width: 706)
    }
    try render(SettingsView(model: model, initialSection: .developer), name: "settings-developer-dark", width: 706, scheme: .dark)
    try render(SettingsView(model: model, initialSection: .agents), name: "settings-agents-dark", width: 706, scheme: .dark)
    model.cliEnabled = false
    try render(WelcomeView(model: model), name: "welcome", width: 520)
    FileHandle.standardOutput.write(Data("Native mock views rendered; session ended Off.\n".utf8))
}
#endif
