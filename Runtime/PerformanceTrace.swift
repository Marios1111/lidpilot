#if LIDPILOT_PROFILE
import Darwin
import Foundation
import OSLog

/// Instrumentation that exists only in explicitly profiled builds.
/// Values passed by production call sites must be fixed categories, opaque
/// UUIDs, booleans, or scalar state; never pass payloads, messages, paths, or errors.
public enum PerformanceTrace {
    private static let state = TraceState()
    private static let logger = Logger(subsystem: "com.lidpilot.profile", category: "events")
    private static let reservedKeys: Set<String> = [
        "schema", "event", "seq", "pid", "uptime_ns", "wall_time"
    ]
    private static let callsiteKey = "com.lidpilot.profile.callsite"
    private static let contextKey = "com.lidpilot.profile.context"
    private static let spanKey = "com.lidpilot.profile.span"

    private final class TraceState: @unchecked Sendable {
        let lock = NSLock()
        let testScopeLock = NSLock()
        var sequence: UInt64 = 0
        var started = false
        var testSink: (@Sendable (Data) -> Void)?
    }

    /// Emit the per-process profile marker once. Call from each process entry
    /// point so an absent marker distinguishes a non-profiled binary.
    public static func start() {
        var payload: Data?
        var sink: (@Sendable (Data) -> Void)?
        state.lock.lock()
        guard !state.started else { state.lock.unlock(); return }
        state.started = true
        payload = makePayloadLocked(event: "profile_start", fields: ["profile_enabled": true],
                                    sequence: nextSequenceLocked())
        sink = state.testSink
        if let payload, let json = String(data: payload, encoding: .utf8) {
            logger.notice("\(json, privacy: .public)")
        }
        state.lock.unlock()
        if let payload { sink?(payload) }
    }

    /// Emit one JSON event with the shared schema and a monotonically assigned
    /// per-process sequence number. Field values should remain low-cardinality
    /// and non-sensitive.
    public static func event(_ name: String, fields: [String: String] = [:]) {
        start()
        let values = fields.filter { !reservedKeys.contains($0.key) }
        emit(name, fields: values)
    }

    /// Scope a synchronous helper read with its call-site reason. Do not span
    /// an `await`: thread-local context is intentionally never propagated.
    public static func withCallsite<T>(_ reason: String, _ body: () throws -> T) rethrows -> T {
        try withThreadValue(reason, key: callsiteKey, body)
    }

    /// Scope fixed request identifiers/state into nested command spans.
    /// This is synchronous and thread-local by design.
    public static func withContext<T>(_ fields: [String: String], _ body: () throws -> T) rethrows -> T {
        try withThreadValue(fields, key: contextKey, body)
    }

    static var currentCallsite: String {
        Thread.current.threadDictionary[callsiteKey] as? String ?? "unspecified"
    }

    static var currentSpanID: String? {
        Thread.current.threadDictionary[spanKey] as? String
    }

    /// Trace a synchronous command span. RUSAGE_CHILDREN reports aggregate CPU
    /// only for children reaped by this process; caller must keep child reaping
    /// serialized around this span for the delta to describe its command.
    public static func span<T>(operation: String, _ body: () throws -> T) rethrows -> T {
        start()
        let spanID = UUID().uuidString.lowercased()
        let startedAt = DispatchTime.now().uptimeNanoseconds
        let cpuBefore = childCPUTime()
        var beginFields: [String: Any] = currentContext
        beginFields["span_id"] = spanID
        beginFields["operation"] = operation
        beginFields["callsite"] = currentCallsite
        emit("pmset_span_begin", fields: beginFields)

        let dictionary = Thread.current.threadDictionary
        let previousSpan = dictionary[spanKey]
        dictionary[spanKey] = spanID
        defer { restore(previousSpan, key: spanKey, dictionary: dictionary) }

        do {
            let result = try body()
            let endedAt = DispatchTime.now().uptimeNanoseconds
            var endFields: [String: Any] = currentContext
            endFields["span_id"] = spanID
            endFields["operation"] = operation
            endFields["callsite"] = currentCallsite
            endFields["result"] = "success"
            endFields["duration_ns"] = endedAt >= startedAt ? endedAt - startedAt : 0

            if let cpuBefore, let cpuAfter = childCPUTime(),
               cpuAfter.userUS >= cpuBefore.userUS,
               cpuAfter.systemUS >= cpuBefore.systemUS {
                endFields["reaped_child_cpu_complete"] = true
                endFields["reaped_child_user_us"] = cpuAfter.userUS - cpuBefore.userUS
                endFields["reaped_child_system_us"] = cpuAfter.systemUS - cpuBefore.systemUS
            } else {
                endFields["reaped_child_cpu_complete"] = false
            }
            emit("pmset_span_end", fields: endFields)
            return result
        } catch {
            var endFields: [String: Any] = currentContext
            endFields["span_id"] = spanID
            endFields["operation"] = operation
            endFields["callsite"] = currentCallsite
            endFields["result"] = "error"
            let endedAt = DispatchTime.now().uptimeNanoseconds
            endFields["duration_ns"] = endedAt >= startedAt ? endedAt - startedAt : 0
            endFields["reaped_child_cpu_complete"] = false
            emit("pmset_span_end", fields: endFields)
            throw error
        }
    }

    private static var currentContext: [String: String] {
        Thread.current.threadDictionary[contextKey] as? [String: String] ?? [:]
    }

    private static func withThreadValue<T>(_ value: Any, key: String,
                                           _ body: () throws -> T) rethrows -> T {
        let dictionary = Thread.current.threadDictionary
        let previous = dictionary[key]
        dictionary[key] = value
        defer { restore(previous, key: key, dictionary: dictionary) }
        return try body()
    }

    private static func restore(_ value: Any?, key: String, dictionary: NSMutableDictionary) {
        if let value { dictionary[key] = value } else { dictionary.removeObject(forKey: key) }
    }

    private static func emit(_ name: String, fields: [String: Any]) {
        var payload: Data?
        var sink: (@Sendable (Data) -> Void)?
        state.lock.lock()
        payload = makePayloadLocked(event: name, fields: fields, sequence: nextSequenceLocked())
        sink = state.testSink
        if let payload, let json = String(data: payload, encoding: .utf8) {
            logger.notice("\(json, privacy: .public)")
        }
        state.lock.unlock()
        if let payload { sink?(payload) }
    }

    private static func nextSequenceLocked() -> UInt64 {
        state.sequence = state.sequence == UInt64.max ? UInt64.max : state.sequence + 1
        return state.sequence
    }

    private static func makePayloadLocked(event: String, fields: [String: Any],
                                          sequence: UInt64) -> Data? {
        var object: [String: Any] = [
            "schema": 1,
            "event": event,
            "seq": sequence,
            "pid": Int(getpid()),
            "uptime_ns": DispatchTime.now().uptimeNanoseconds,
            "wall_time": Date().timeIntervalSince1970
        ]
        for (key, value) in fields where !reservedKeys.contains(key) { object[key] = value }
        return try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private struct ChildCPU {
        let userUS: UInt64
        let systemUS: UInt64
    }

    /// Darwin getrusage expresses timeval seconds and microseconds; this helper
    /// emits deltas in microseconds, and only when both samples are monotonic.
    private static func childCPUTime() -> ChildCPU? {
        var usage = rusage()
        guard getrusage(RUSAGE_CHILDREN, &usage) == 0,
              let user = microseconds(usage.ru_utime),
              let system = microseconds(usage.ru_stime) else { return nil }
        return ChildCPU(userUS: user, systemUS: system)
    }

    private static func microseconds(_ value: timeval) -> UInt64? {
        let seconds = Int64(value.tv_sec)
        let micros = Int64(value.tv_usec)
        guard seconds >= 0, (0..<1_000_000).contains(micros) else { return nil }
        let (whole, secondsOverflow) = UInt64(seconds).multipliedReportingOverflow(by: 1_000_000)
        let (total, microsOverflow) = whole.addingReportingOverflow(UInt64(micros))
        guard !secondsOverflow, !microsOverflow else { return nil }
        return total
    }

    #if DEBUG
    static func formattedEventForTesting(_ name: String, sequence: UInt64, pid: Int32,
                                         uptimeNS: UInt64, wallTime: Double,
                                         fields: [String: Any] = [:]) -> Data? {
        var object: [String: Any] = [
            "schema": 1,
            "event": name,
            "seq": sequence,
            "pid": Int(pid),
            "uptime_ns": uptimeNS,
            "wall_time": wallTime
        ]
        for (key, value) in fields where !reservedKeys.contains(key) { object[key] = value }
        return try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    static func withEventSinkForTesting<T>(_ sink: @escaping @Sendable (Data) -> Void,
                                           _ body: () throws -> T) rethrows -> T {
        state.testScopeLock.lock()
        defer { state.testScopeLock.unlock() }
        state.lock.lock()
        let previous = state.testSink
        state.testSink = sink
        state.lock.unlock()
        defer {
            state.lock.lock()
            state.testSink = previous
            state.lock.unlock()
        }
        return try body()
    }
    #endif
}
#endif
