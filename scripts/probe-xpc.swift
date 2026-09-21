// Developer-only XPC authentication probe; this file is not part of the app target.
//
// From the repository root, compile without signing, registering, or installing anything:
//   swiftc -swift-version 6 -parse-as-library \
//     -module-cache-path /private/tmp/lidpilot-probe-module-cache \
//     Core/Sources/LidPilotCore/*.swift scripts/probe-xpc.swift \
//     -o /private/tmp/lidpilot-probe-xpc
//
// The signed positive/negative-client identity probe keeps its no-argument invocation:
//   /private/tmp/lidpilot-probe-xpc
//
// To check the helper's invalid-wire rejection using an authorized signed client:
//   /private/tmp/lidpilot-probe-xpc --invalid-wire
// That fixed mode sends four requests: inspect with protocol version 2, inspect with
// generation 0, truncated inspect JSON, and valid inspect JSON padded with whitespace to
// 16 KiB + 1. It checks locally that the generated payloads cannot decode as valid
// WireRequests. Every helper response must be success=false with failureCode=invalidRequest.
//
// Run only after confirming LidPilot is Off, no owned override or pending recovery journal
// exists, and baseline SleepDisabled is 0. HelperEngine runs bootstrap and its safety
// watchdog before a valid inspect reply, while normal connection teardown also runs helper
// disconnect cleanup. These paths can perform existing recovery housekeeping. Do not run
// during an active session. The probe has no payload, command, path, or timeout options.
//
// No-argument exit codes: 0 reply received, 2 proxy/transport error, 3 connection
// interruption or invalidation, 4 bounded timeout, 5 malformed reply, and 64 incorrect
// invocation. --invalid-wire exits 0 only when all four typed invalidRequest assertions pass,
// 1 on any unexpected reply or transport outcome, 70 if local fixture checks fail, and 64 on
// incorrect invocation. A transport error or interruption may be an authentication
// rejection, but this probe cannot prove the cause. A timeout is inconclusive and never
// proves that authentication was rejected.

import Darwin
import Foundation

@objc private protocol HelperXPCProtocol {
    func exchange(_ payload: Data, reply: @escaping @Sendable (Data) -> Void)
}

private enum ProbeOutcome: Sendable {
    case reply(success: Bool, failureCode: String?)
    case proxyError(domain: String, code: Int)
    case interrupted
    case invalidated
    case malformedReply
    case timeout
}

private struct InvalidWireCase {
    let name: String
    let payload: Data
}

private enum InvalidWireFixtureError: Error {
    case baseRequestWasNotInspect
    case locallyAccepted(String)
    case malformedFixtureWasValidJSON
    case oversizedRequestWasNotValidJSON
}

private final class ProbeCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var outcome: ProbeOutcome?

    func finish(_ outcome: ProbeOutcome) {
        lock.lock()
        let isFirst = self.outcome == nil
        if isFirst { self.outcome = outcome }
        lock.unlock()
        if isFirst { semaphore.signal() }
    }

    func wait(timeout: DispatchTimeInterval) -> ProbeOutcome {
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            finish(.timeout)
        }
        lock.lock()
        defer { lock.unlock() }
        return outcome ?? .timeout
    }
}

@main
private struct XPCProbe {
    private static let serviceName = "com.lidpilot.app.helper"
    // Mirrors HelperIdentity.requirement for the currently configured publisher team.
    private static let helperRequirement = #"anchor apple generic and identifier "com.lidpilot.app.helper" and certificate leaf[subject.OU] = "L69774LN97""#
    private static let timeout: DispatchTimeInterval = .seconds(10)

    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        switch arguments {
        case []:
            Darwin.exit(runInspectProbe())
        case ["--invalid-wire"]:
            Darwin.exit(runInvalidWireProbe())
        default:
            write("outcome=invalid_invocation; usage: /private/tmp/lidpilot-probe-xpc [--invalid-wire]\n")
            Darwin.exit(64)
        }
    }

    private static func fixedInspectPayload() throws -> Data {
        let request = WireRequest(
            operation: .inspect,
            sessionID: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            generation: 1
        )
        return try request.encoded()
    }

    private static func runInspectProbe() -> Int32 {
        do {
            return report(exchange(try fixedInspectPayload()))
        } catch {
            write("outcome=local_encoding_error\n")
            return 70
        }
    }

    private static func runInvalidWireProbe() -> Int32 {
        let cases: [InvalidWireCase]
        do {
            cases = try invalidWireCases()
        } catch {
            write("outcome=local_fixture_error; detail=\(String(describing: error))\n")
            return 70
        }

        var allPassed = true
        for testCase in cases {
            let outcome = exchange(testCase.payload)
            let passed: Bool
            if case let .reply(success, failureCode) = outcome {
                passed = !success && failureCode == WireFailureCode.invalidRequest.rawValue
            } else {
                passed = false
            }
            write("case=\(testCase.name); \(describe(outcome)); assertion=\(passed ? "pass" : "FAIL")\n")
            allPassed = allPassed && passed
        }
        return allPassed ? 0 : 1
    }

    private static func invalidWireCases() throws -> [InvalidWireCase] {
        let validInspect = try fixedInspectPayload()
        let baseObject = try jsonObject(from: validInspect)
        guard let operation = baseObject["operation"] as? String,
              operation == WireOperation.inspect.rawValue,
              let generation = baseObject["generation"] as? Int,
              generation == 1 else {
            throw InvalidWireFixtureError.baseRequestWasNotInspect
        }

        var wrongProtocolObject = baseObject
        wrongProtocolObject["protocolVersion"] = WireRequest.protocolVersion + 1
        let wrongProtocol = try jsonData(from: wrongProtocolObject)

        var zeroGenerationObject = baseObject
        zeroGenerationObject["generation"] = 0
        let zeroGeneration = try jsonData(from: zeroGenerationObject)

        let malformedJSON = Data(#"{"protocolVersion":1,"operation":"inspect""#.utf8)
        guard (try? JSONSerialization.jsonObject(with: malformedJSON)) == nil else {
            throw InvalidWireFixtureError.malformedFixtureWasValidJSON
        }

        guard validInspect.count <= WireRequest.maximumEncodedSize else {
            throw InvalidWireFixtureError.baseRequestWasNotInspect
        }
        var oversizedInspect = validInspect
        oversizedInspect.append(Data(
            repeating: 0x20,
            count: WireRequest.maximumEncodedSize + 1 - oversizedInspect.count
        ))
        guard oversizedInspect.count == WireRequest.maximumEncodedSize + 1,
              let oversizedObject = try? JSONSerialization.jsonObject(with: oversizedInspect),
              oversizedObject is [String: Any] else {
            throw InvalidWireFixtureError.oversizedRequestWasNotValidJSON
        }

        let cases = [
            InvalidWireCase(name: "wrong-protocol-inspect", payload: wrongProtocol),
            InvalidWireCase(name: "zero-generation-inspect", payload: zeroGeneration),
            InvalidWireCase(name: "malformed-inspect-json", payload: malformedJSON),
            InvalidWireCase(name: "oversized-valid-inspect-json", payload: oversizedInspect)
        ]
        for testCase in cases {
            guard (try? WireRequest.decode(testCase.payload)) == nil else {
                throw InvalidWireFixtureError.locallyAccepted(testCase.name)
            }
        }
        return cases
    }

    private static func jsonObject(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InvalidWireFixtureError.baseRequestWasNotInspect
        }
        return object
    }

    private static func jsonData(from object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private static func exchange(_ payload: Data) -> ProbeOutcome {
        let completion = ProbeCompletion()
        let connection = NSXPCConnection(machServiceName: serviceName, options: .privileged)
        connection.setCodeSigningRequirement(helperRequirement)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        connection.interruptionHandler = { completion.finish(.interrupted) }
        connection.invalidationHandler = { completion.finish(.invalidated) }
        connection.activate()

        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            let nsError = error as NSError
            completion.finish(.proxyError(domain: nsError.domain, code: nsError.code))
        }
        if let endpoint = proxy as? HelperXPCProtocol {
            endpoint.exchange(payload) { data in
                guard let reply = try? WireReply.decode(data) else {
                    completion.finish(.malformedReply)
                    return
                }
                completion.finish(.reply(
                    success: reply.success,
                    failureCode: reply.failureCode?.rawValue
                ))
            }
        } else {
            completion.finish(.proxyError(domain: "NSXPCInterface", code: 0))
        }

        let outcome = completion.wait(timeout: timeout)
        connection.invalidate()
        return outcome
    }

    private static func report(_ outcome: ProbeOutcome) -> Int32 {
        write("\(describe(outcome))\n")
        switch outcome {
        case .reply: return 0
        case .proxyError: return 2
        case .interrupted, .invalidated: return 3
        case .timeout: return 4
        case .malformedReply: return 5
        }
    }

    private static func describe(_ outcome: ProbeOutcome) -> String {
        switch outcome {
        case let .reply(success, failureCode):
            return "outcome=reply; success=\(success); failure_code=\(failureCode ?? "none")"
        case let .proxyError(domain, code):
            return "outcome=proxy_error_or_transport_rejection; domain=\(domain); code=\(code)"
        case .interrupted:
            return "outcome=connection_interrupted; rejection_is_not_proven"
        case .invalidated:
            return "outcome=connection_invalidated; rejection_is_not_proven"
        case .malformedReply:
            return "outcome=malformed_reply"
        case .timeout:
            return "outcome=timeout; authentication_rejection_not_proven"
        }
    }

    private static func write(_ message: String) {
        FileHandle.standardOutput.write(Data(message.utf8))
    }
}
