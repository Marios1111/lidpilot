import Foundation
import Security
import LidPilotCore

public enum HelperIdentity {
    public static let appID = "com.lidpilot.app"
    public static let helperID = "com.lidpilot.app.helper"
    public static let plist = "com.lidpilot.app.helper.plist"
    public static let developmentAppID = "com.lidpilot.app.dev"
    public static let developmentHelperID = "com.lidpilot.app.dev.helper"
    public static let developmentPlist = "com.lidpilot.app.dev.helper.plist"

    public struct Configuration: Equatable, Sendable {
        public let appIdentifier: String
        public let helperIdentifier: String
        public let serviceIdentifier: String
        public let daemonLabel: String
        public let daemonPlistName: String
        public let userStateDirectoryName: String
        public let isProduction: Bool

        let recoveryDirectory: String
        let commandFenceDirectory: String

        fileprivate init(appIdentifier: String, helperIdentifier: String, daemonPlistName: String,
                         userStateDirectoryName: String, isProduction: Bool,
                         recoveryDirectory: String, commandFenceDirectory: String) {
            self.appIdentifier = appIdentifier
            self.helperIdentifier = helperIdentifier
            serviceIdentifier = helperIdentifier
            daemonLabel = helperIdentifier
            self.daemonPlistName = daemonPlistName
            self.userStateDirectoryName = userStateDirectoryName
            self.isProduction = isProduction
            self.recoveryDirectory = recoveryDirectory
            self.commandFenceDirectory = commandFenceDirectory
        }
    }

    private static let production = Configuration(
        appIdentifier: appID,
        helperIdentifier: helperID,
        daemonPlistName: plist,
        userStateDirectoryName: "LidPilot",
        isProduction: true,
        recoveryDirectory: "/Library/Application Support/LidPilot",
        commandFenceDirectory: "/Library/Application Support/LidPilot"
    )

    private static let development = Configuration(
        appIdentifier: developmentAppID,
        helperIdentifier: developmentHelperID,
        daemonPlistName: developmentPlist,
        userStateDirectoryName: "LidPilot Development",
        isProduction: false,
        recoveryDirectory: "/Library/Application Support/LidPilot Development",
        // Both helper identities serialize access to the same system-wide SleepDisabled flag.
        commandFenceDirectory: "/Library/Application Support/LidPilot"
    )

    private static let configurations = [production, development]

    /// Returns a configuration only for an exact, known app/helper pair.
    public static func configuration(appIdentifier: String?, helperIdentifier: String?) -> Configuration? {
        guard let appIdentifier, let helperIdentifier else { return nil }
        return configurations.first {
            $0.appIdentifier == appIdentifier && $0.helperIdentifier == helperIdentifier
        }
    }

    /// Uses the two embedded bundle identities, never a bundle-derived path or service name.
    public static func applicationConfiguration() -> Configuration? {
        configuration(
            appIdentifier: Bundle.main.bundleIdentifier,
            helperIdentifier: Bundle.main.object(forInfoDictionaryKey: "LidPilotHelperIdentifier") as? String
        )
    }

    /// The privileged helper must identify itself and its matching app before opening state.
    public static func helperConfiguration() -> Configuration? {
        configuration(
            appIdentifier: Bundle.main.object(forInfoDictionaryKey: "LidPilotHostBundleIdentifier") as? String,
            helperIdentifier: Bundle.main.bundleIdentifier
        )
    }

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

    public static func applicationRequirement(for configuration: Configuration, team: String) throws -> String {
        guard configurations.contains(configuration) else {
            throw RuntimeFailure.unavailable("Invalid signing identity.")
        }
        return try requirement(identifier: configuration.appIdentifier, team: team)
    }

    public static func helperRequirement(for configuration: Configuration, team: String) throws -> String {
        guard configurations.contains(configuration) else {
            throw RuntimeFailure.unavailable("Invalid signing identity.")
        }
        return try requirement(identifier: configuration.helperIdentifier, team: team)
    }

    private static func requirement(identifier: String, team: String) throws -> String {
        let allowedIdentifiers = configurations.flatMap { [$0.appIdentifier, $0.helperIdentifier] }
        guard allowedIdentifiers.contains(identifier), team.count == 10,
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

final class ReplyOnce: @unchecked Sendable {
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

enum XPCTransportCallbacks {
    static func remoteErrorHandler(for once: ReplyOnce) -> @Sendable (any Error) -> Void {
        { error in once.finish(.failure(error)) }
    }

    static func replyHandler(for once: ReplyOnce) -> @Sendable (Data) -> Void {
        { data in once.finish(.success(data)) }
    }

    static func timeoutHandler(for once: ReplyOnce) -> @Sendable () -> Void {
        { once.finish(.failure(RuntimeFailure.unavailable("The helper did not reply in time."))) }
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
        guard let configuration = HelperIdentity.applicationConfiguration() else {
            throw RuntimeFailure.unavailable("This app bundle does not have a recognized LidPilot helper identity.")
        }
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
            let requirement = try HelperIdentity.helperRequirement(for: configuration, team: HelperIdentity.ownTeam())
            channel = NSXPCConnection(machServiceName: configuration.serviceIdentifier, options: .privileged)
            channel.setCodeSigningRequirement(requirement)
            channel.remoteObjectInterface = NSXPCInterface(with: HelperXPCProtocol.self)
            channel.activate()
            connection = channel
        }
        do {
            let data: Data = try await withCheckedThrowingContinuation { continuation in
                let once = ReplyOnce(continuation)
                let proxy = channel.remoteObjectProxyWithErrorHandler(XPCTransportCallbacks.remoteErrorHandler(for: once))
                guard let endpoint = proxy as? HelperXPCProtocol else {
                    once.finish(.failure(RuntimeFailure.unavailable("The helper interface is unavailable.")))
                    return
                }
                endpoint.exchange(payload, reply: XPCTransportCallbacks.replyHandler(for: once))
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30,
                                                               execute: XPCTransportCallbacks.timeoutHandler(for: once))
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
