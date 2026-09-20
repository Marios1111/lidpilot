// Developer-only XPC authentication probe; this file is not part of the app target.
//
// From the repository root, compile without signing, registering, or installing anything:
//   swiftc -swift-version 6 -parse-as-library \
//     -module-cache-path /private/tmp/lidpilot-probe-module-cache \
//     Core/Sources/LidPilotCore/*.swift scripts/probe-xpc.swift \
//     -o /private/tmp/lidpilot-probe-xpc
//
// An operator may then sign a disposable copy as needed and run it with no arguments:
//   /private/tmp/lidpilot-probe-xpc
//
// Run only after confirming LidPilot is Off, no owned override or pending recovery journal
// exists, and baseline SleepDisabled is 0. HelperEngine runs bootstrap and its safety
// watchdog before answering even an inspect request, so that path can perform existing
// recovery housekeeping. Do not run during an active session. This probe sends exactly one
// fixed, read-only `inspect` request; it has no payload, command, or timeout options.
//
// Exit codes: 0 reply received (client reached the helper), 2 proxy/transport error, 3
// connection interruption or invalidation, 4 bounded timeout, 5 malformed reply, and 64
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
        guard CommandLine.arguments.count == 1 else {
            write("outcome=invalid_invocation; usage: /private/tmp/lidpilot-probe-xpc\n")
            Darwin.exit(64)
        }

        let request = WireRequest(
            operation: .inspect,
            sessionID: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            generation: 1
        )
        let payload: Data
        do {
            payload = try request.encoded()
        } catch {
            write("outcome=local_encoding_error\n")
            Darwin.exit(70)
        }

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
        report(outcome)
    }

    private static func report(_ outcome: ProbeOutcome) {
        switch outcome {
        case let .reply(success, failureCode):
            write("outcome=reply; success=\(success); failure_code=\(failureCode ?? "none")\n")
            Darwin.exit(0)
        case let .proxyError(domain, code):
            write("outcome=proxy_error_or_transport_rejection; domain=\(domain); code=\(code)\n")
            Darwin.exit(2)
        case .interrupted:
            write("outcome=connection_interrupted; rejection_is_not_proven\n")
            Darwin.exit(3)
        case .invalidated:
            write("outcome=connection_invalidated; rejection_is_not_proven\n")
            Darwin.exit(3)
        case .malformedReply:
            write("outcome=malformed_reply\n")
            Darwin.exit(5)
        case .timeout:
            write("outcome=timeout; authentication_rejection_not_proven\n")
            Darwin.exit(4)
        }
    }

    private static func write(_ message: String) {
        FileHandle.standardOutput.write(Data(message.utf8))
    }
}
