#!/usr/bin/env swift
// Local validation tool; not linked into or shipped with LidPilot.
import Foundation
import Darwin

struct Reading: Codable {
    let pid: Int32
    let started: UInt64
    let userTicks: UInt64
    let systemTicks: UInt64
    let childUserTicks: UInt64
    let childSystemTicks: UInt64
    let physicalBytes: UInt64
    let interruptWakeups: UInt64
    let idleWakeups: UInt64
    let energyNanojoules: UInt64
}
struct Sample: Codable {
    let elapsedSeconds: Double
    let processes: [Reading]
}
struct TargetCPU: Codable {
    let pid: Int32
    let ownUserTicks: UInt64
    let ownSystemTicks: UInt64
    let reapedChildUserTicks: UInt64
    let reapedChildSystemTicks: UInt64
    let inclusiveCPUPercentOfOneCore: Double
}
struct Report: Codable {
    let label: String
    let startedAt: Date
    let startedAtUnixSeconds: Double
    let endedAtUnixSeconds: Double
    let durationSeconds: Double
    let machTimebaseNumerator: UInt32
    let machTimebaseDenominator: UInt32
    let cpuPercentOfOneCoreIncludingReapedChildren: Double
    let cpuByTarget: [TargetCPU]
    let meanCombinedPhysicalMiB: Double
    let maxSampledCombinedPhysicalMiB: Double
    let interruptWakeupsPerSecond: Double
    let packageIdleWakeupsPerSecond: Double
    let reportedEnergyNanojoules: UInt64
    let notes: String
    let samples: [Sample]
}

func read(_ pid: Int32) throws -> Reading {
    var info = rusage_info_v6()
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
            proc_pid_rusage(pid, RUSAGE_INFO_V6, $0)
        }
    }
    guard result == 0 else {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno),
                      userInfo: [NSLocalizedDescriptionKey: "Cannot read PID \(pid); no measurement result may be inferred."])
    }
    return Reading(pid: pid, started: info.ri_proc_start_abstime,
                   userTicks: info.ri_user_time, systemTicks: info.ri_system_time,
                   childUserTicks: info.ri_child_user_time, childSystemTicks: info.ri_child_system_time,
                   physicalBytes: info.ri_phys_footprint,
                   interruptWakeups: info.ri_interrupt_wkups, idleWakeups: info.ri_pkg_idle_wkups,
                   energyNanojoules: info.ri_energy_nj)
}

do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count >= 4, let duration = Double(args[0]), duration.isFinite,
          (1...7200).contains(duration) else {
        throw NSError(domain: "usage", code: 64, userInfo: [NSLocalizedDescriptionKey:
            "usage: measure-performance SECONDS LABEL OUTPUT.json PID [PID ...]; use 600 seconds for release evidence"])
    }
    let pids = try args.dropFirst(3).map { value -> Int32 in
        guard let pid = Int32(value), pid > 0 else { throw NSError(domain: "PID", code: 64) }
        return pid
    }
    guard Set(pids).count == pids.count, !FileManager.default.fileExists(atPath: args[2]) else {
        throw NSError(domain: "input", code: 64, userInfo: [NSLocalizedDescriptionKey: "Duplicate PID or existing output file"])
    }
    var timebase = mach_timebase_info_data_t()
    guard mach_timebase_info(&timebase) == KERN_SUCCESS else { throw NSError(domain: "clock", code: 1) }
    guard timebase.numer > 0, timebase.denom > 0 else {
        throw NSError(domain: "clock", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Mach returned an invalid timebase"])
    }
    let secondsPerTick = Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
    guard secondsPerTick.isFinite, secondsPerTick > 0 else {
        throw NSError(domain: "clock", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Mach timebase cannot be converted to seconds"])
    }
    let startedAt = Date()
    let start = mach_absolute_time()
    let initial = try pids.map(read)
    var samples = [Sample(elapsedSeconds: 0, processes: initial)]
    while true {
        let elapsed = Double(mach_absolute_time() - start) * secondsPerTick
        if elapsed >= duration { break }
        Thread.sleep(forTimeInterval: min(5, duration - elapsed))
        let values = try pids.map(read)
        guard zip(values, initial).allSatisfy({ $0.started == $1.started }) else {
            throw NSError(domain: "process", code: 1, userInfo: [NSLocalizedDescriptionKey: "A target PID was replaced; discard this run"])
        }
        samples.append(Sample(elapsedSeconds: Double(mach_absolute_time() - start) * secondsPerTick,
                              processes: values))
    }
    let elapsed = samples.last!.elapsedSeconds
    let final = samples.last!.processes
    guard elapsed.isFinite, elapsed > 0 else {
        throw NSError(domain: "clock", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Elapsed measurement time is invalid"])
    }
    func difference(_ current: UInt64, _ previous: UInt64, field: String, pid: Int32? = nil) throws -> UInt64 {
        guard current >= previous else {
            let target = pid.map { " for PID \($0)" } ?? ""
            throw NSError(domain: "counter", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Nonmonotonic \(field) counter\(target); discard this run"])
        }
        return current - previous
    }
    func checkedAdd(_ lhs: UInt64, _ rhs: UInt64, field: String) throws -> UInt64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow else {
            throw NSError(domain: "counter", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Overflow while summing \(field) counters; discard this run"])
        }
        return value
    }
    guard final.count == initial.count else {
        throw NSError(domain: "process", code: 1, userInfo: [NSLocalizedDescriptionKey:
            "The target process set changed; discard this run"])
    }
    func delta(_ field: KeyPath<Reading, UInt64>, name: String) throws -> UInt64 {
        var total: UInt64 = 0
        for (last, first) in zip(final, initial) {
            let amount = try difference(last[keyPath: field], first[keyPath: field], field: name, pid: first.pid)
            total = try checkedAdd(total, amount, field: name)
        }
        return total
    }
    // CPU accounting uses Mach absolute-time units. Include reaped power-command
    // children; do not substitute wall time or relabel these counters as ns.
    var cpuByTarget = [TargetCPU]()
    var cpuTicks: UInt64 = 0
    for (last, first) in zip(final, initial) {
        let user = try difference(last.userTicks, first.userTicks, field: "user CPU", pid: first.pid)
        let system = try difference(last.systemTicks, first.systemTicks, field: "system CPU", pid: first.pid)
        let childUser = try difference(last.childUserTicks, first.childUserTicks,
                                       field: "reaped-child user CPU", pid: first.pid)
        let childSystem = try difference(last.childSystemTicks, first.childSystemTicks,
                                         field: "reaped-child system CPU", pid: first.pid)
        let targetTicks = try checkedAdd(try checkedAdd(user, system, field: "target CPU"),
                                         try checkedAdd(childUser, childSystem, field: "reaped-child CPU"),
                                         field: "inclusive target CPU")
        cpuTicks = try checkedAdd(cpuTicks, targetTicks, field: "inclusive process-tree CPU")
        cpuByTarget.append(TargetCPU(pid: first.pid, ownUserTicks: user, ownSystemTicks: system,
                                     reapedChildUserTicks: childUser, reapedChildSystemTicks: childSystem,
                                     inclusiveCPUPercentOfOneCore:
                                        Double(targetTicks) * secondsPerTick / elapsed * 100))
    }
    let memory = samples.map { $0.processes.reduce(0.0) { $0 + Double($1.physicalBytes) } / 1_048_576 }
    let report = Report(label: args[1], startedAt: startedAt,
                        startedAtUnixSeconds: startedAt.timeIntervalSince1970,
                        endedAtUnixSeconds: Date().timeIntervalSince1970, durationSeconds: elapsed,
                        machTimebaseNumerator: timebase.numer, machTimebaseDenominator: timebase.denom,
                        cpuPercentOfOneCoreIncludingReapedChildren: Double(cpuTicks) * secondsPerTick / elapsed * 100,
                        cpuByTarget: cpuByTarget,
                        meanCombinedPhysicalMiB: memory.reduce(0,+) / Double(memory.count),
                        maxSampledCombinedPhysicalMiB: memory.max()!,
                        interruptWakeupsPerSecond: Double(try delta(\.interruptWakeups, name: "interrupt wakeup")) / elapsed,
                        packageIdleWakeupsPerSecond: Double(try delta(\.idleWakeups, name: "package idle wakeup")) / elapsed,
                        reportedEnergyNanojoules: try delta(\.energyNanojoules, name: "energy"),
                        notes: "Public proc_pid_rusage V6; 5-second samples. CPU tick fields are converted using the recorded Mach timebase numerator/denominator. Per-target inclusive CPU includes that PID's reaped children and sums to the combined value when target process trees do not overlap. Zero energy counters may mean unavailable accounting, not zero energy. This is not Activity Monitor's Energy Impact score. PID restarts, nonmonotonic counters or read failures invalidate the run. Physical footprint is sampled, not an absolute transient peak. Record mode, build, power and display state separately; this tool cannot verify them.",
                        samples: samples)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(report).write(to: URL(fileURLWithPath: args[2]), options: .withoutOverwriting)
    print("Recorded \(elapsed) seconds for \(args[1]) in \(args[2])")
} catch {
    FileHandle.standardError.write(Data("Performance measurement failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
