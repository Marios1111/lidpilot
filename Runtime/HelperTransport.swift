import Foundation
import Security
import LidPilotCore

public enum HelperIdentity {
    public static let appID = "com.lidpilot.app"
    public static let helperID = "com.lidpilot.app.helper"
    public static let plist = "com.lidpilot.app.helper.plist"

    public static func ownTeam() throws -> String {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var information: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let values = information as? [String: Any],
              let team = values[kSecCodeInfoTeamIdentifier as String] as? String else {
            throw RuntimeFailure.unavailable("A publisher-signed build is required for the privileged helper.")
        }
        return team
    }

    public static func requirement(identifier: String, team: String) throws -> String {
        guard [appID, helperID].contains(identifier), team.count == 10,
              team.unicodeScalars.allSatisfy({ (65...90).contains($0.value) || (48...57).contains($0.value) }) else {
            throw RuntimeFailure.unavailable("Invalid signing identity.")
        }
        let value = "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(team)\""
        var parsed: SecRequirement?
        guard SecRequirementCreateWithString(value as CFString, [], &parsed) == errSecSuccess else {
            throw RuntimeFailure.unavailable("The peer signing requirement is invalid.")
        }
        return value
    }
}

@objc public protocol HelperXPCProtocol {
    func exchange(_ payload: Data, reply: @escaping @Sendable (Data) -> Void)
}

@MainActor public protocol HelperTransport: AnyObject {
    func send(_ request: WireRequest) async throws -> WireReply
    func disconnect()
}

private final class ReplyOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, any Error>?
    init(_ continuation: CheckedContinuation<Data, any Error>) { self.continuation = continuation }
    func finish(_ result: Result<Data, any Error>) {
        lock.lock()
        let waiting = continuation
        continuation = nil
        lock.unlock()
        waiting?.resume(with: result)
    }
}

@MainActor public final class XPCTransport: HelperTransport {
    private var connection: NSXPCConnection?
    private var verifiedBuild: String?
    private let build: String
    public init(build: String) { self.build = build }

    public func disconnect() {
        connection?.invalidate()
        connection = nil
        verifiedBuild = nil
    }

    public func send(_ request: WireRequest) async throws -> WireReply {
        #if LIDPILOT_PROFILE
        PerformanceTrace.event("xpc", fields: ["direction": "send", "op": request.operation.rawValue, "session_id": request.sessionID.uuidString])
        defer { PerformanceTrace.event("xpc", fields: ["direction": "complete", "op": request.operation.rawValue]) }
        #endif
        let activates = request.operation == .acquire || request.operation == .renew
        if activates, verifiedBuild != build {
            let status = try await send(WireRequest(operation: .inspect, sessionID: request.sessionID, generation: request.generation))
            guard status.helperBuild == build else {
                throw RuntimeFailure.unavailable("The installed helper needs repair for this app version.")
            }
        }
        let payload = try request.encoded()
        let channel: NSXPCConnection
        if let connection { channel = connection } else {
            let requirement = try HelperIdentity.requirement(identifier: HelperIdentity.helperID, team: HelperIdentity.ownTeam())
            channel = NSXPCConnection(machServiceName: HelperIdentity.helperID, options: .privileged)
            channel.setCodeSigningRequirement(requirement)
            channel.remoteObjectInterface = NSXPCInterface(with: HelperXPCProtocol.self)
            channel.activate()
            connection = channel
        }
        do {
            let data: Data = try await withCheckedThrowingContinuation { continuation in
                let once = ReplyOnce(continuation)
                let proxy = channel.remoteObjectProxyWithErrorHandler { error in once.finish(.failure(error)) }
                guard let endpoint = proxy as? HelperXPCProtocol else {
                    once.finish(.failure(RuntimeFailure.unavailable("The helper interface is unavailable.")))
                    return
                }
                endpoint.exchange(payload) { once.finish(.success($0)) }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30) {
                    once.finish(.failure(RuntimeFailure.unavailable("The helper did not reply in time.")))
                }
            }
            let reply = try WireReply.decode(data)
            verifiedBuild = reply.helperBuild
            // Compatible old helpers must remain reachable for inspection and safe cleanup.
            guard !activates || reply.helperBuild == build else {
                throw RuntimeFailure.unavailable("The installed helper needs to be replaced for this app version.")
            }
            return reply
        } catch {
            disconnect()
            throw error
        }
    }
}
