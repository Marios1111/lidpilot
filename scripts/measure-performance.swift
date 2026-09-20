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
struct Report: Codable {
    let label: String
    let startedAt: Date
    let durationSeconds: Double
    let cpuPercentOfOneCoreIncludingReapedChildren: Double
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
    let secondsPerTick = Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
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
    func delta(_ field: KeyPath<Reading, UInt64>) throws -> UInt64 {
        var total: UInt64 = 0
        for (last, first) in zip(final, initial) {
            guard last[keyPath: field] >= first[keyPath: field] else { throw NSError(domain: "counter", code: 1) }
            total += last[keyPath: field] - first[keyPath: field]
        }
        return total
    }
    // CPU accounting uses Mach absolute-time units. Include reaped power-command
    // children; do not substitute wall time or relabel these counters as ns.
    let cpuTicks = try delta(\.userTicks) + delta(\.systemTicks) + delta(\.childUserTicks) + delta(\.childSystemTicks)
    let memory = samples.map { $0.processes.reduce(0.0) { $0 + Double($1.physicalBytes) } / 1_048_576 }
    let report = Report(label: args[1], startedAt: startedAt, durationSeconds: elapsed,
                        cpuPercentOfOneCoreIncludingReapedChildren: Double(cpuTicks) * secondsPerTick / elapsed * 100,
                        meanCombinedPhysicalMiB: memory.reduce(0,+) / Double(memory.count),
                        maxSampledCombinedPhysicalMiB: memory.max()!,
                        interruptWakeupsPerSecond: Double(try delta(\.interruptWakeups)) / elapsed,
                        packageIdleWakeupsPerSecond: Double(try delta(\.idleWakeups)) / elapsed,
                        reportedEnergyNanojoules: try delta(\.energyNanojoules),
                        notes: "Public proc_pid_rusage V6; 5-second samples. Zero energy counters may mean unavailable accounting, not zero energy. This is not Activity Monitor's Energy Impact score. PID restarts or read failures invalidate the run. Physical footprint is sampled, not an absolute transient peak. Record mode, build, power and display state separately; this tool cannot verify them.",
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
