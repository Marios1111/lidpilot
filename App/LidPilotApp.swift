import SwiftUI
import AppKit
import LidPilotCore
import LidPilotRuntime

@main struct LidPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: AppModel
    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        delegate.model = model
    }
    var body: some Scene {
        MenuBarExtra {
            PilotPanel(model: model)
                .onAppear { delegate.model = model; model.refreshHelper() }
        } label: {
            Image(systemName: model.controller.hasSession ? "laptopcomputer.and.arrow.down" : "laptopcomputer")
                .accessibilityLabel("LidPilot, \(model.controller.phase.rawValue)")
        }
        .menuBarExtraStyle(.window)

        #if DEBUG
        Window("LidPilot · UI Preview", id: "ui-preview") {
            if model.isPreview { PilotPanel(model: model).onAppear { delegate.model = model } }
        }
        .defaultLaunchBehavior(model.isPreview ? .presented : .suppressed)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        #endif

        Window("LidPilot Settings", id: "settings") {
            SettingsView(model: model).onAppear { delegate.model = model; model.refreshHelper() }
        }
        .defaultLaunchBehavior(.suppressed)
        .defaultSize(width: 640, height: 520)
        .windowResizability(.contentSize)

        Window("Welcome to LidPilot", id: "welcome") {
            WelcomeView(model: model).onAppear { delegate.model = model }
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .defaultSize(width: 520, height: 440)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    private var terminationRequested = false
    private var cleanupConfirmed = false
    private var iconAppearanceObservation: NSKeyValueObservation?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Update only on appearance changes, never on a timer. Finder retains
        // the default icon; the running app uses the matching native variant.
        iconAppearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.initial, .new]) { _, _ in
            Task { @MainActor in
                guard let artwork = NSImage(named: "PilotIcon") else { return }
                // 256 points produces a 512-pixel Retina icon without the larger
                // offscreen bitmap copies. Finder retains the full bundle icon.
                let icon = NSImage(size: NSSize(width: 256, height: 256))
                NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
                    icon.lockFocus()
                    artwork.draw(in: NSRect(x: 0, y: 0, width: 256, height: 256))
                    icon.unlockFocus()
                }
                NSApp.applicationIconImage = icon
            }
        }
        #if DEBUG
        if let model, model.isPreview,
           let directory = ProcessInfo.processInfo.environment["LIDPILOT_PREVIEW_CAPTURE_DIR"] {
            Task { @MainActor in
                do { try await renderPreviewSnapshots(model: model, directory: directory) }
                catch { FileHandle.standardError.write(Data("Preview export failed: \(error)\n".utf8)) }
                NSApp.terminate(nil)
            }
        }
        #endif
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if cleanupConfirmed { return .terminateNow }
        guard let model else { return .terminateNow }
        if model.updater?.canTerminate == false {
            let alert = NSAlert()
            alert.messageText = "Finish the update with the lid open"
            alert.informativeText = "LidPilot is holding new sessions while the update is pending. Open the lid and finish the update before quitting."
            alert.runModal()
            return .terminateCancel
        }
        guard !terminationRequested else { return .terminateCancel }
        terminationRequested = true
        Task { @MainActor in
            await model.controller.stop()
            let clean = model.controller.phase == .off
            if clean, model.updater?.canTerminate != false {
                model.stopObserving()
                cleanupConfirmed = true
                NSApp.terminate(nil)
            }
            else {
                terminationRequested = false
                let alert = NSAlert()
                alert.messageText = "Cleanup needs attention"
                alert.informativeText = model.controller.message + " Open Settings → Helper & Recovery to check the helper."
                alert.addButton(withTitle: "Keep LidPilot Open")
                alert.runModal()
            }
        }
        // Returning now lets the current Swift concurrency job finish. A nested
        // AppKit terminate-later loop can otherwise starve its cleanup Task.
        return .terminateCancel
    }
}

extension Mode {
    var symbol: String {
        switch self { case .smart: "laptopcomputer.and.arrow.down"; case .display: "display"; case .closed: "laptopcomputer" }
    }
    var detail: String {
        switch self {
        case .smart: "Screen ready when open. Work on when closed."
        case .display: "For lectures, notes, and reading along."
        case .closed: "For long tasks, with the lid open or closed."
        }
    }
}

extension SessionPhase {
    var title: String {
        switch self {
        case .off: "Off"
        case .starting: "Starting…"
        case .active: "Session active"
        case .stopping: "Turning off…"
        case .paused: "Paused"
        case .unverified: "Unverified"
        case .recovery: "Recovery required"
        case .updating: "Preparing update"
        }
    }
    var color: Color {
        switch self { case .active: .green; case .paused, .unverified, .recovery: .orange; case .starting, .stopping, .updating: .accentColor; case .off: .secondary }
    }
}
