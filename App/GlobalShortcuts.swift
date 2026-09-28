import AppKit
import Carbon
import Observation
import SwiftUI

enum ShortcutAction: String, CaseIterable, Identifiable {
    case openPanel
    case toggleSession
    case smart
    case display
    case closed

    var id: Self { self }

    var title: String {
        switch self {
        case .openPanel: "Open LidPilot"
        case .toggleSession: "Start or stop session"
        case .smart: "Follow Lid"
        case .display: "Keep Screen On"
        case .closed: "Keep Mac Running"
        }
    }
}

struct ShortcutBinding: Equatable {
    let keyCode: UInt16
    let modifiers: UInt32
    let keyLabel: String

    var label: String {
        var parts: [String] = []
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        parts.append(keyLabel)
        return parts.joined()
    }

    fileprivate var isAllowed: Bool {
        let command = UInt32(cmdKey)
        let control = UInt32(controlKey)
        let option = UInt32(optionKey)
        let shift = UInt32(shiftKey)
        let supported = command | control | option | shift
        guard modifiers & ~supported == 0 else { return false }

        let count = [command, control, option, shift].filter { modifiers & $0 != 0 }.count
        return count >= 2 &&
            (modifiers & command != 0 || (modifiers & control != 0 && modifiers & option != 0))
    }
}

@MainActor @Observable final class GlobalShortcuts {
    private static let storageKey = "globalShortcuts.v1"
    private struct RegisteredHotKey {
        let id: UInt32
        let reference: EventHotKeyRef
    }

    private(set) var bindings: [ShortcutAction: ShortcutBinding]
    private(set) var error: String?
    private(set) var status = "No shortcuts assigned."
    private(set) var isEnabled: Bool

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let onAction: @MainActor (ShortcutAction) -> Void
    @ObservationIgnored private let hotKeySignature: OSType
    @ObservationIgnored private var registered: [ShortcutAction: RegisteredHotKey] = [:]
    @ObservationIgnored private var actionByHotKeyID: [UInt32: ShortcutAction] = [:]
    @ObservationIgnored private var eventHandler: EventHandlerRef?
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var nextHotKeyID: UInt32 = 1

    init(defaults: UserDefaults = .standard, enabled: Bool = true,
         onAction: @escaping @MainActor (ShortcutAction) -> Void) {
        self.defaults = defaults
        self.isEnabled = enabled
        self.onAction = onAction
        hotKeySignature = OSType.random(in: UInt32.min...UInt32.max)
        bindings = Self.loadBindings(from: defaults)
        if enabled { start() }
    }

    func start() {
        guard isEnabled, !isRunning else { return }
        guard !bindings.isEmpty else {
            isRunning = true
            error = nil
            status = "No shortcuts assigned."
            return
        }
        guard installEventHandler() else { return }
        isRunning = true

        var firstError: String?
        for action in ShortcutAction.allCases {
            guard let binding = bindings[action] else { continue }
            if let registration = register(binding, for: action) {
                registered[action] = registration
                actionByHotKeyID[registration.id] = action
            } else if firstError == nil {
                firstError = error
            }
        }
        error = firstError
        let count = registered.count
        status = firstError.map { _ in "Some shortcuts could not be registered." } ??
            "\(count) shortcut\(count == 1 ? "" : "s") ready."
    }

    /// Stops owned Carbon registrations but preserves the user's saved assignments.
    func stop() {
        for registration in registered.values {
            UnregisterEventHotKey(registration.reference)
        }
        registered.removeAll()
        actionByHotKeyID.removeAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        isRunning = false
        status = "Global shortcuts are paused."
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        if enabled { start() } else { stop() }
    }

    @discardableResult
    func setShortcut(for action: ShortcutAction, keyCode: UInt16,
                     modifiers: NSEvent.ModifierFlags, keyLabel: String) -> Bool {
        let carbonModifiers = Self.carbonModifiers(from: modifiers)
        let binding = ShortcutBinding(keyCode: keyCode, modifiers: carbonModifiers,
                                      keyLabel: keyLabel.isEmpty ? "Key \(keyCode)" : keyLabel.uppercased())
        guard binding.isAllowed else {
            error = "Use Command with another modifier, or Control + Option, and a key."
            return false
        }
        if let duplicate = bindings.first(where: { $0.key != action && $0.value.keyCode == keyCode && $0.value.modifiers == carbonModifiers }) {
            error = "That shortcut is already assigned to \(duplicate.key.title)."
            return false
        }
        if let existing = bindings[action], existing.keyCode == binding.keyCode,
           existing.modifiers == binding.modifiers,
           (!isRunning || !isEnabled || registered[action] != nil) {
            bindings[action] = binding
            saveBindings()
            error = nil
            status = "\(action.title) shortcut set to \(binding.label)."
            return true
        }

        // Register first so a system conflict leaves the previous working shortcut intact.
        let replacement: RegisteredHotKey?
        if isRunning && isEnabled {
            guard installEventHandler() else { return false }
            guard let value = register(binding, for: action) else { return false }
            replacement = value
        } else {
            replacement = nil
        }

        if let previous = registered.removeValue(forKey: action) {
            UnregisterEventHotKey(previous.reference)
            actionByHotKeyID.removeValue(forKey: previous.id)
        }
        bindings[action] = binding
        if let replacement {
            registered[action] = replacement
            actionByHotKeyID[replacement.id] = action
        }
        saveBindings()
        error = nil
        status = "\(action.title) shortcut set to \(binding.label)."
        return true
    }

    func clearShortcut(for action: ShortcutAction) {
        guard bindings.removeValue(forKey: action) != nil else { return }
        if let previous = registered.removeValue(forKey: action) {
            UnregisterEventHotKey(previous.reference)
            actionByHotKeyID.removeValue(forKey: previous.id)
        }
        saveBindings()
        error = nil
        status = "\(action.title) shortcut cleared."
    }

    func shortcut(for action: ShortcutAction) -> ShortcutBinding? {
        bindings[action]
    }

    private func installEventHandler() -> Bool {
        guard eventHandler == nil else { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        var reference: EventHandlerRef?
        let result = InstallEventHandler(GetApplicationEventTarget(), Self.handleHotKeyEvent,
                                         1, &eventType, userData, &reference)
        guard result == noErr, let reference else {
            error = "Could not install the global shortcut handler (OSStatus \(result))."
            status = "Global shortcut registration failed."
            return false
        }
        eventHandler = reference
        return true
    }

    @discardableResult
    private func register(_ binding: ShortcutBinding, for action: ShortcutAction) -> RegisteredHotKey? {
        guard eventHandler != nil else {
            error = "The global shortcut handler is unavailable."
            return nil
        }
        let id = nextHotKeyID
        nextHotKeyID &+= 1
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: id)
        var reference: EventHotKeyRef?
        let result = RegisterEventHotKey(UInt32(binding.keyCode), binding.modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &reference)
        guard result == noErr, let reference else {
            error = "Could not register \(action.title) shortcut; macOS or another app may already use it (OSStatus \(result))."
            status = "Global shortcut registration failed."
            return nil
        }
        let registration = RegisteredHotKey(id: id, reference: reference)
        return registration
    }

    private func handleHotKey(id: UInt32) {
        guard isEnabled, isRunning, let action = actionByHotKeyID[id] else { return }
        onAction(action)
    }

    private func saveBindings() {
        var stored: [String: [String: Any]] = [:]
        for (action, binding) in bindings {
            stored[action.rawValue] = [
                "keyCode": Int(binding.keyCode),
                "modifiers": Int(binding.modifiers),
                "keyLabel": binding.keyLabel
            ]
        }
        defaults.set(stored, forKey: Self.storageKey)
    }

    private static func loadBindings(from defaults: UserDefaults) -> [ShortcutAction: ShortcutBinding] {
        guard let stored = defaults.dictionary(forKey: storageKey) else { return [:] }
        var result: [ShortcutAction: ShortcutBinding] = [:]
        for (rawAction, value) in stored {
            guard let action = ShortcutAction(rawValue: rawAction), let fields = value as? [String: Any],
                  let keyCode = (fields["keyCode"] as? NSNumber)?.uint16Value,
                  let modifierNumber = fields["modifiers"] as? NSNumber,
                  modifierNumber.int64Value >= 0,
                  modifierNumber.int64Value <= Int64(UInt32.max) else { continue }
            let binding = ShortcutBinding(keyCode: keyCode, modifiers: modifierNumber.uint32Value,
                                          keyLabel: fields["keyLabel"] as? String ?? "Key \(keyCode)")
            guard binding.isAllowed else { continue }
            result[action] = binding
        }

        // Ignore stale duplicate entries rather than allowing persisted conflicts to register twice.
        var seen = Set<String>()
        for action in ShortcutAction.allCases {
            guard let binding = result[action] else { continue }
            let signature = "\(binding.keyCode):\(binding.modifiers)"
            if !seen.insert(signature).inserted { result.removeValue(forKey: action) }
        }
        return result
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private static let handleHotKeyEvent: EventHandlerProcPtr = { _, event, userData in
        guard let event, let userData else { return OSStatus(eventNotHandledErr) }
        var identifier = EventHotKeyID()
        let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                       EventParamType(typeEventHotKeyID), nil,
                                       MemoryLayout<EventHotKeyID>.size, nil, &identifier)
        guard result == noErr else { return result }
        let shortcuts = Unmanaged<GlobalShortcuts>.fromOpaque(userData).takeUnretainedValue()
        guard identifier.signature == shortcuts.hotKeySignature else { return OSStatus(eventNotHandledErr) }
        Task { @MainActor [weak shortcuts] in shortcuts?.handleHotKey(id: identifier.id) }
        return noErr
    }
}

struct ShortcutSettingsView: View {
    let shortcuts: GlobalShortcuts
    @State private var recording: ShortcutAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(ShortcutAction.allCases) { action in
                HStack(spacing: 10) {
                    Text(action.title).font(.subheadline)
                    Spacer(minLength: 8)
                    if recording == action {
                        ShortcutCaptureField { keyCode, modifiers, keyLabel in
                            if shortcuts.setShortcut(for: action, keyCode: keyCode,
                                                     modifiers: modifiers, keyLabel: keyLabel) {
                                recording = nil
                            }
                        } onCancel: {
                            recording = nil
                        }
                        .frame(width: 175, height: 28)
                        .accessibilityLabel("Shortcut recorder for \(action.title)")
                        .accessibilityValue("Press a shortcut")
                        .accessibilityHint("Press Command with another modifier, or Control and Option, then a key. Press Escape to cancel.")

                        Button("Cancel") { recording = nil }
                            .accessibilityLabel("Cancel recording \(action.title) shortcut")
                    } else {
                        Button(shortcuts.shortcut(for: action)?.label ?? "Set Shortcut") {
                            recording = action
                        }
                        .accessibilityLabel("\(shortcuts.shortcut(for: action) == nil ? "Set" : "Change") shortcut for \(action.title)")
                        .accessibilityHint("Record a global keyboard shortcut. Command must be paired with another modifier, or use Control and Option.")

                        if shortcuts.shortcut(for: action) != nil {
                            Button("Clear") { shortcuts.clearShortcut(for: action) }
                                .accessibilityLabel("Clear \(action.title) shortcut")
                        }
                    }
                }
            }
            Text("No Accessibility permission is needed.")
                .font(.caption).foregroundStyle(.secondary)
            Text(shortcuts.status).font(.caption).foregroundStyle(.secondary)
            if let error = shortcuts.error {
                Text(error).font(.caption).foregroundStyle(.orange).accessibilityLabel("Shortcut error: \(error)")
            }
        }
    }
}

private struct ShortcutCaptureField: NSViewRepresentable {
    let onCapture: @MainActor (UInt16, NSEvent.ModifierFlags, String) -> Void
    let onCancel: @MainActor () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ view: ShortcutCaptureNSView, context: Context) {
        view.onCapture = onCapture
        view.onCancel = onCancel
        if view.window?.firstResponder !== view {
            DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        }
    }
}

@MainActor private final class ShortcutCaptureNSView: NSView {
    var onCapture: (@MainActor (UInt16, NSEvent.ModifierFlags, String) -> Void)?
    var onCancel: (@MainActor () -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }
        let keyLabel = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        onCapture?(event.keyCode, event.modifierFlags, keyLabel)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        (window?.firstResponder === self ? NSColor.selectedContentBackgroundColor : NSColor.controlBackgroundColor).setFill()
        path.fill()
        let title = "Press shortcut"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: window?.firstResponder === self ? NSColor.selectedTextColor : NSColor.secondaryLabelColor
        ]
        let size = title.size(withAttributes: attributes)
        title.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2),
                   withAttributes: attributes)
    }
}
