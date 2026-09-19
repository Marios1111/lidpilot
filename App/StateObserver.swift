import AppKit
import IOKit
import IOKit.ps

@MainActor final class StateObserver {
    var onChange: (() -> Void)?
    var onSleep: (() -> Void)?
    private var subscriptions: [(NotificationCenter, NSObjectProtocol)] = []
    private var powerSource: CFRunLoopSource?
    private var notificationPort: IONotificationPortRef?
    private var root: io_service_t = 0
    private var interest: io_object_t = 0

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didWakeNotification)
        observe(workspace, NSWorkspace.screensDidWakeNotification)
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification)
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification, sleep: true)
        observe(workspace, NSWorkspace.willSleepNotification, sleep: true)
        observe(.default, NSApplication.didChangeScreenParametersNotification)
        observe(.default, ProcessInfo.thermalStateDidChangeNotification)
        observe(.default, Notification.Name.NSProcessInfoPowerStateDidChange)

        let context = Unmanaged.passUnretained(self).toOpaque()
        powerSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let owner = Unmanaged<StateObserver>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in owner.onChange?() }
        }, context)?.takeRetainedValue()
        if let powerSource { CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .commonModes) }

        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        if let notificationPort {
            IONotificationPortSetDispatchQueue(notificationPort, .main)
            root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
            if root != 0 {
                IOServiceAddInterestNotification(notificationPort, root, kIOGeneralInterest, { context, _, _, _ in
                    guard let context else { return }
                    let owner = Unmanaged<StateObserver>.fromOpaque(context).takeUnretainedValue()
                    Task { @MainActor in owner.onChange?() }
                }, context, &interest)
            }
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, sleep: Bool = false) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                if sleep { self?.onSleep?() } else { self?.onChange?() }
            }
        }
        subscriptions.append((center, token))
    }

    func stop() {
        subscriptions.forEach { $0.0.removeObserver($0.1) }
        subscriptions.removeAll()
        if let powerSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .commonModes) }
        powerSource = nil
        if interest != 0 { IOObjectRelease(interest); interest = 0 }
        if root != 0 { IOObjectRelease(root); root = 0 }
        if let notificationPort { IONotificationPortDestroy(notificationPort) }
        notificationPort = nil
    }
}
