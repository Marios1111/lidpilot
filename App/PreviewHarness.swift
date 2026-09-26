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
    func apply(system: Bool, display: Bool, timeout: Double) throws -> AssertionState {
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
    model.selectedMode = .smart
    model.duration = .hour
    await model.controller.refreshWhileOff()
    try render(PilotPanel(model: model), name: "panel-off-light", width: 370)
    try render(PilotPanel(model: model), name: "panel-off-dark", width: 370, scheme: .dark)
    await model.controller.start(mode: .smart, duration: .seconds(3600), policy: model.policy)
    guard model.controller.phase == .active, model.controller.effectiveMode == .smart else {
        throw RuntimeFailure.unavailable("Mock session activation failed.")
    }
    try render(PilotPanel(model: model), name: "panel-active", width: 370)
    await model.controller.stop()
    guard model.controller.phase == .off, model.controller.assertions == .off else {
        throw RuntimeFailure.unavailable("Mock cleanup failed.")
    }
    // Product presentation uses the actual native views with the preview label
    // intact. Each fixture activates and cleans up only simulated controls.
    for (mode, name) in [(Mode.display, "keep-screen-on"), (.closed, "keep-mac-running")] {
        model.selectedMode = mode
        await model.controller.start(mode: mode, duration: .seconds(3600), policy: model.policy)
        guard model.controller.phase == .active, model.controller.effectiveMode == mode else {
            throw RuntimeFailure.unavailable("Product preview activation failed.")
        }
        try render(PilotPanel(model: model), name: name, width: 370)
        await model.controller.stop()
        guard model.controller.phase == .off, model.controller.assertions == .off else {
            throw RuntimeFailure.unavailable("Product preview cleanup failed.")
        }
    }
    try render(SettingsView(model: model), name: "settings", width: 650)
    try render(WelcomeView(model: model), name: "welcome", width: 520)
    FileHandle.standardOutput.write(Data("Native mock views rendered; session ended Off.\n".utf8))
}
#endif
