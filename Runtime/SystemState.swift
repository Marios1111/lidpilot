import Foundation
import Darwin
import IOKit
import IOKit.ps
import CoreGraphics
import LidPilotCore

public protocol RuntimeClock: Sendable {
    func now() -> ClockSample
}

public struct SystemClock: RuntimeClock {
    private let bootID: String
    private let secondsPerTick: Double

    public init() {
        var size = 0
        sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0)
        var bytes = [CChar](repeating: 0, count: max(size, 1))
        if sysctlbyname("kern.bootsessionuuid", &bytes, &size, nil, 0) == 0 {
            bootID = String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        } else {
            // An unavailable boot identity must not make persisted deadlines reusable.
            bootID = UUID().uuidString
        }
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        secondsPerTick = Double(info.numer) / Double(info.denom) / 1_000_000_000
    }

    public func now() -> ClockSample {
        ClockSample(continuousSeconds: Double(mach_continuous_time()) * secondsPerTick,
                    wallDate: Date(), bootID: bootID)
    }
}

public protocol PowerSampling: Sendable {
    func sample(flag: FlagState) -> PowerSnapshot
}

/// Only public observation APIs and documented IOPM registry keys. Never adjusts brightness.
public struct SystemPowerSampler: PowerSampling {
    private let clock: any RuntimeClock
    public init(clock: any RuntimeClock = SystemClock()) { self.clock = clock }

    public func sample(flag: FlagState = .unknown) -> PowerSnapshot {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        var lid: LidState = .unknown
        if root != 0 {
            if let value = IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString,
                                                          kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool {
                lid = value ? .closed : .open
            }
            IOObjectRelease(root)
        }

        var power: PowerSource = .unknown
        var battery: Int?
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
            if let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? {
                if type == kIOPSACPowerValue { power = .external }
                if type == kIOPSBatteryPowerValue { power = .battery }
            }
            if let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
                for source in sources {
                    guard let value = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                          value[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                          let current = value[kIOPSCurrentCapacityKey] as? Int,
                          let maximum = value[kIOPSMaxCapacityKey] as? Int,
                          maximum > 0, current >= 0, current <= maximum else { continue }
                    battery = Int(Double(current) / Double(maximum) * 100)
                    break
                }
            }
        }

        let thermal: ThermalLevel
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .unknown
        }
        var count: UInt32 = 0
        var topology: Int?
        if CGGetOnlineDisplayList(0, nil, &count) == .success, count <= 64 {
            var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
            if CGGetOnlineDisplayList(count, &ids, &count) == .success {
                topology = ids.prefix(Int(count)).filter { CGDisplayIsBuiltin($0) == 0 }.count
            }
        }
        return PowerSnapshot(sampledAt: clock.now(), lid: lid, power: power, batteryPercent: battery,
                             thermal: thermal, lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                             externalDisplayCount: topology, sleepDisabled: flag)
    }
}
