import SwiftUI
import AppKit
import UserNotifications
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
        #if DEBUG
        Window("LidPilot · UI Preview", id: "ui-preview") {
            if model.isPreview {
                PilotPanel(model: model, onSettings: { delegate.showSettings() }, onWelcome: { delegate.showWelcome() })
                    .onAppear { delegate.model = model }
            }
        }
        .defaultLaunchBehavior(model.isPreview ? .presented : .suppressed)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        #endif

        Settings { SettingsView(model: model) }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { delegate.showSettings() }.keyboardShortcut(",", modifiers: .command)
                }
            }

    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    weak var model: AppModel?
    private var terminationRequested = false
    private var cleanupConfirmed = false
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var iconAppearanceObservation: NSKeyValueObservation?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMenuBar()
        // The center keeps its delegate weakly. SwiftUI's application adaptor
        // retains this delegate for the lifetime of the process.
        if model?.isPreview != true {
            UNUserNotificationCenter.current().delegate = self
        }
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
    private func installMenuBar() {
        guard let model else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        let panel = NSPopover()
        panel.behavior = .transient
        panel.contentViewController = NSHostingController(rootView: PilotPanel(model: model,
            onSettings: { [weak self] in self?.showSettings() },
            onWelcome: { [weak self] in self?.showWelcome() }))
        popover = panel
        model.openPanel = { [weak self] in self?.togglePanel() }
        model.onStatusChange = { [weak self] in self?.refreshMenuBar() }
        refreshMenuBar()
    }

    private func refreshMenuBar() {
        guard let model, let button = statusItem?.button else { return }
        let symbol = model.controller.hasSession ? "laptopcomputer.and.arrow.down" : "laptopcomputer"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "LidPilot, \(model.controller.phase.title)")
        button.image?.isTemplate = true
        button.toolTip = "LidPilot · \(model.controller.phase.title)"
    }

    @objc private func togglePanel() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            model?.refreshHelper()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    fileprivate func showSettings() {
        guard let model else { return }
        popover?.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "LidPilot Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    fileprivate func showWelcome() {
        guard let model else { return }
        popover?.performClose(nil)
        if welcomeWindow == nil {
            let view = WelcomeView(model: model, onDismiss: { [weak self] in self?.welcomeWindow?.close() })
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Welcome to LidPilot"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            welcomeWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        welcomeWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.settingsWindow?.isVisible != true && self.welcomeWindow?.isVisible != true {
                NSApp.setActivationPolicy(.accessory)
            }
        }
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

nonisolated extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor [weak self] in
            guard self?.model?.isPreview == false, self?.model?.notify == true else {
                completionHandler([])
                return
            }
            if let model = self?.model {
                model.diagnostics.record(model.controller.phase, "Requested foreground notification banner, list and sound from macOS.")
            }
            completionHandler([.banner, .list, .sound])
        }
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
