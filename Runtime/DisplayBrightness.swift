import CoreGraphics
import ColorSync
import Darwin
import Foundation

@MainActor public protocol DisplayBrightnessControlling: AnyObject {
    func setDimmed(_ dimmed: Bool) throws
}

struct BrightnessDisplay: Equatable {
    let id: CGDirectDisplayID
    let uuid: UUID
}

struct BrightnessTargetCache {
    private var remembered: [BrightnessDisplay] = []
    mutating func resolve(online: [BrightnessDisplay], isStillBuiltIn: (BrightnessDisplay) -> Bool) -> [BrightnessDisplay] {
        let candidates = online + remembered.filter { old in !online.contains(where: { $0.id == old.id }) }
        remembered = candidates.filter(isStillBuiltIn)
        return remembered
    }
}

@MainActor protocol DisplayBrightnessBackend: AnyObject {
    func builtInDisplays() throws -> [BrightnessDisplay]
    func get(_ display: BrightnessDisplay) throws -> Float
    func set(_ value: Float, on display: BrightnessDisplay) throws
}

struct BrightnessRecovery: Codable, Equatable {
    let version: Int
    let displayUUID: UUID
    let original: Float
    init(displayUUID: UUID, original: Float) {
        version = 1
        self.displayUUID = displayUUID
        self.original = original
    }
}

@MainActor protocol BrightnessRecoveryStoring: AnyObject {
    func load() throws -> BrightnessRecovery?
    func save(_ record: BrightnessRecovery) throws
    func clear() throws
}

/// A narrowly scoped, explicitly authorized private API exception. This changes only
/// the built-in display's brightness value, never automatic brightness or True Tone.
@MainActor public final class NativeDisplayBrightness: DisplayBrightnessControlling {
    private let backend: any DisplayBrightnessBackend
    private let journal: any BrightnessRecoveryStoring
    private var dimAttempted = false
    private var dimVerified = false
    private static let tolerance: Float = 0.001

    public convenience init() {
        self.init(backend: DisplayServicesBrightnessBackend(), journal: DefaultsBrightnessRecovery())
    }

    init(backend: any DisplayBrightnessBackend, journal: any BrightnessRecoveryStoring) {
        self.backend = backend
        self.journal = journal
    }

    public func setDimmed(_ dimmed: Bool) throws {
        if dimmed, dimAttempted {
            guard dimVerified else { throw failure("Brightness dimming is awaiting recovery.") }
            return // Do not fight the user's adjustment or automatic brightness on heartbeats.
        }
        let pending = try journal.load()
        if let pending {
            guard pending.version == 1, valid(pending.original) else {
                throw failure("The brightness recovery record is invalid.")
            }
            if dimmed {
                // A previous instance may have crashed; restore before starting another cycle.
                throw failure("Restore pending display brightness before dimming again.")
            }
            let matches = try backend.builtInDisplays().filter { $0.uuid == pending.displayUUID }
            guard matches.count == 1, let display = matches.first else {
                throw failure("The built-in display needed for brightness recovery is unavailable.")
            }
            let current = try read(display)
            if current == 0 {
                try backend.set(pending.original, on: display)
                guard abs(try read(display) - pending.original) <= Self.tolerance else {
                    throw failure("Restored display brightness could not be verified.")
                }
            }
            // A nonzero value belongs to the user or macOS; never overwrite it.
            try journal.clear()
            dimAttempted = false
            dimVerified = false
            return
        }
        guard dimmed else {
            dimAttempted = false
            dimVerified = false
            // Best-effort read-only preparation while open. No pending recovery means
            // unavailable control must not make an otherwise ordinary cleanup fail.
            _ = try? backend.builtInDisplays()
            return
        }
        let displays = try backend.builtInDisplays()
        guard displays.count == 1, let display = displays.first else {
            throw failure("A unique built-in display is required for brightness dimming.")
        }
        let original = try read(display)
        // Persist before the first write, including its possible partial failure.
        try journal.save(BrightnessRecovery(displayUUID: display.uuid, original: original))
        dimAttempted = true
        try backend.set(0, on: display)
        guard try read(display) == 0 else {
            throw failure("Zero display brightness could not be verified.")
        }
        dimVerified = true
    }

    private func read(_ display: BrightnessDisplay) throws -> Float {
        let value = try backend.get(display)
        guard valid(value) else { throw failure("The display returned an invalid brightness value.") }
        return value
    }

    private func valid(_ value: Float) -> Bool { value.isFinite && (0...1).contains(value) }
    private func failure(_ message: String) -> RuntimeFailure { .unavailable(message) }
}

@MainActor final class DefaultsBrightnessRecovery: BrightnessRecoveryStoring {
    private let defaults: UserDefaults
    private let key = "builtInBrightnessRecovery.v1"

    // The app's domain keeps production and development recovery isolated.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> BrightnessRecovery? {
        guard let object = defaults.object(forKey: key) else { return nil }
        guard let data = object as? Data, !data.isEmpty, data.count <= 1024 else {
            throw RuntimeFailure.unavailable("The brightness recovery record is damaged.")
        }
        return try JSONDecoder().decode(BrightnessRecovery.self, from: data)
    }

    func save(_ record: BrightnessRecovery) throws {
        defaults.set(try JSONEncoder().encode(record), forKey: key)
        guard defaults.synchronize() else {
            throw RuntimeFailure.unavailable("Brightness recovery could not be saved.")
        }
    }

    func clear() throws {
        let previous = defaults.object(forKey: key)
        defaults.removeObject(forKey: key)
        guard defaults.synchronize() else {
            // Retain pending recovery in memory too if persistence fails.
            if let previous { defaults.set(previous, forKey: key) }
            throw RuntimeFailure.unavailable("Brightness recovery could not be cleared.")
        }
    }
}

@MainActor private final class DisplayServicesBrightnessBackend: DisplayBrightnessBackend {
    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32
    // Keep the framework loaded for the process lifetime; function pointers remain valid.
    private var getBrightness: GetBrightness?
    private var setBrightness: SetBrightness?
    private var targets = BrightnessTargetCache()

    func builtInDisplays() throws -> [BrightnessDisplay] {
        try load()
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count <= 128 else {
            throw unavailable()
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { throw unavailable() }
        let online = try ids.prefix(Int(count)).filter { CGDisplayIsBuiltin($0) != 0 }.map { id in
            guard let uuid = displayUUID(id) else {
                throw unavailable()
            }
            return BrightnessDisplay(id: id, uuid: uuid)
        }
        // Lid closure can remove the panel from the online list. A cached target is
        // usable only while both its built-in classification and UUID still match.
        return targets.resolve(online: online) { display in
            CGDisplayIsBuiltin(display.id) != 0 && displayUUID(display.id) == display.uuid
        }
    }

    func get(_ display: BrightnessDisplay) throws -> Float {
        try verify(display)
        try load()
        var value: Float = .nan
        guard getBrightness?(display.id, &value) == 0 else { throw unavailable() }
        return value
    }

    func set(_ value: Float, on display: BrightnessDisplay) throws {
        try verify(display)
        try load()
        guard value.isFinite, (0...1).contains(value), setBrightness?(display.id, value) == 0 else {
            throw unavailable()
        }
    }

    private func verify(_ display: BrightnessDisplay) throws {
        // Revalidate both built-in status and stable identity immediately before every call.
        guard try builtInDisplays().contains(display) else { throw unavailable() }
    }

    private func displayUUID(_ id: CGDirectDisplayID) -> UUID? {
        guard let value = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return UUID(uuidString: CFUUIDCreateString(nil, value) as String)
    }

    private func load() throws {
        if getBrightness != nil, setBrightness != nil { return }
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY | RTLD_LOCAL) else {
            throw unavailable()
        }
        guard let get = dlsym(handle, "DisplayServicesGetBrightness"),
              let set = dlsym(handle, "DisplayServicesSetBrightness") else {
            dlclose(handle)
            throw unavailable()
        }
        getBrightness = unsafeBitCast(get, to: GetBrightness.self)
        setBrightness = unsafeBitCast(set, to: SetBrightness.self)
    }

    private func unavailable() -> RuntimeFailure {
        .unavailable("Built-in display brightness control is unavailable on this Mac.")
    }
}
