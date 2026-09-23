#if LIDPILOT_PROFILE
import Foundation
import Testing
@testable import LidPilotRuntime

private final class TraceEventBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Data] = []

    func append(_ data: Data) {
        lock.lock(); storage.append(data); lock.unlock()
    }

    var events: [[String: Any]] {
        lock.lock(); defer { lock.unlock() }
        return storage.compactMap { data in
            (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
    }
}

struct PerformanceTraceTests {
    @Test func formatterUsesFlatNumericSchemaAndProtectsReservedFields() throws {
        let payload = try #require(PerformanceTrace.formattedEventForTesting(
            "test_event", sequence: 41, pid: 17, uptimeNS: 9_000_000_001,
            wallTime: 1_800_000_000.25,
            fields: ["event": "spoofed", "value": "fixed"]
        ))
        let event = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])

        #expect(event["schema"] as? Int == 1)
        #expect(event["event"] as? String == "test_event")
        #expect(event["seq"] as? UInt64 == 41)
        #expect(event["pid"] as? Int == 17)
        #expect(event["uptime_ns"] as? UInt64 == 9_000_000_001)
        #expect(event["wall_time"] as? Double == 1_800_000_000.25)
        #expect(event["value"] as? String == "fixed")
    }

    @Test func commandSpanEmitsOnePairedSpanWithMonotonicSequenceAndNumericTotals() throws {
        let buffer = TraceEventBuffer()
        let operation = "test_span_\(UUID().uuidString.lowercased())"
        let result = try PerformanceTrace.withEventSinkForTesting({ buffer.append($0) }) {
            try PerformanceTrace.withCallsite("test") {
                try PerformanceTrace.withContext(["session_id": UUID().uuidString.lowercased(), "generation": "7"]) {
                    try PerformanceTrace.span(operation: operation) {
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
                        try process.run()
                        process.waitUntilExit()
                        return process.terminationStatus
                    }
                }
            }
        }
        #expect(result == 0)

        let spanEvents = buffer.events.filter { $0["operation"] as? String == operation }
        let begins = spanEvents.filter { $0["event"] as? String == "pmset_span_begin" }
        let ends = spanEvents.filter { $0["event"] as? String == "pmset_span_end" }
        let begin = try #require(begins.first)
        let end = try #require(ends.first)

        #expect(begins.count == 1)
        #expect(ends.count == 1)
        #expect(begin["span_id"] as? String == end["span_id"] as? String)
        #expect(begin["callsite"] as? String == "test")
        #expect(begin["session_id"] as? String != nil)
        #expect(begin["generation"] as? String == "7")
        #expect(end["result"] as? String == "success")
        #expect(end["duration_ns"] as? UInt64 != nil)
        #expect(end["reaped_child_cpu_complete"] as? Bool == true)
        #expect(end["reaped_child_user_us"] as? UInt64 != nil)
        #expect(end["reaped_child_system_us"] as? UInt64 != nil)

        let sequences = spanEvents.compactMap { $0["seq"] as? UInt64 }
        #expect(sequences.count == 2)
        #expect(sequences[0] < sequences[1])
    }

    @Test func failedSpanDoesNotReportChildCPUAsComplete() throws {
        struct ExpectedFailure: Error {}
        let buffer = TraceEventBuffer()
        let operation = "test_error_\(UUID().uuidString.lowercased())"
        var didThrow = false

        PerformanceTrace.withEventSinkForTesting({ buffer.append($0) }) {
            do {
                try PerformanceTrace.span(operation: operation) { throw ExpectedFailure() }
            } catch is ExpectedFailure {
                didThrow = true
            } catch {
                Issue.record("Unexpected error type")
            }
        }

        let end = try #require(buffer.events.first {
            $0["event"] as? String == "pmset_span_end" && $0["operation"] as? String == operation
        })
        #expect(didThrow)
        #expect(end["result"] as? String == "error")
        #expect(end["reaped_child_cpu_complete"] as? Bool == false)
        #expect(end["reaped_child_user_us"] == nil)
        #expect(end["reaped_child_system_us"] == nil)
    }

    @Test func callsiteScopeRestoresAfterNestedScopes() {
        let original = PerformanceTrace.currentCallsite
        PerformanceTrace.withCallsite("watchdog") {
            #expect(PerformanceTrace.currentCallsite == "watchdog")
            PerformanceTrace.withCallsite("reply") {
                #expect(PerformanceTrace.currentCallsite == "reply")
            }
            #expect(PerformanceTrace.currentCallsite == "watchdog")
        }
        #expect(PerformanceTrace.currentCallsite == original)
    }
}
#endif
