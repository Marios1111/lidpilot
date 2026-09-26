import Foundation
import SystemConfiguration
import Darwin
import LidPilotCore

/// One request may be outstanding globally; no client backlog can starve the safety check.
final class HelperAdmission: @unchecked Sendable {
    private let lock = NSLock()
    private var occupied = false
    func begin() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !occupied else { return false }
        occupied = true
        return true
    }
    func end() { lock.lock(); occupied = false; lock.unlock() }
}

/// Commands and recovery share a serial executor and an inherited process fence.
public final class HelperService: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.lidpilot.helper.state", qos: .utility)
    private let lock = NSLock()
    private let admission = HelperAdmission()
    private var watchdogQueued = false
    private var clients = 0
    private let engine: HelperEngine
    private let peerRequirement: String
    private var watchdog: DispatchSourceTimer?

    public init(engine: HelperEngine, configuration: HelperIdentity.Configuration, team: String) throws {
        guard HelperIdentity.helperConfiguration() == configuration else {
            throw RuntimeFailure.unavailable("The helper bundle identity does not match its requested service configuration.")
        }
        self.engine = engine
        peerRequirement = try HelperIdentity.applicationRequirement(for: configuration, team: team)
        super.init()
    }

    public func startWatchdog() {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: 10, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            #if LIDPILOT_PROFILE
            PerformanceTrace.event("watchdog", fields: ["stage": "fire"])
            #endif
            self.lock.lock()
            guard !self.watchdogQueued else { self.lock.unlock(); return }
            self.watchdogQueued = true
            self.lock.unlock()
            self.queue.async {
                self.engine.watchdog()
                self.lock.lock(); self.watchdogQueued = false; self.lock.unlock()
            }
        }
        watchdog = timer
        timer.resume()
    }

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard let name = SCDynamicStoreCopyConsoleUser(nil, &uid, &gid) as String?,
              name != "loginwindow", uid != 0, connection.effectiveUserIdentifier == uid else { return false }
        lock.lock()
        guard clients < 4 else { lock.unlock(); return false }
        clients += 1
        lock.unlock()
        let endpoint = HelperEndpoint(service: self, userID: uid)
        connection.setCodeSigningRequirement(peerRequirement)
        connection.exportedInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        connection.exportedObject = endpoint
        connection.invalidationHandler = { [weak self] in
            endpoint.close()
            guard let self else { return }
            // Retain the admission slot until queued disconnect cleanup has run.
            self.queue.async {
                self.lock.lock(); self.clients -= 1; self.lock.unlock()
            }
        }
        connection.interruptionHandler = { endpoint.close() }
        connection.activate()
        return true
    }

    fileprivate func submit(_ payload: Data, endpoint: HelperEndpoint, reply: @escaping @Sendable (Data) -> Void) {
        guard admission.begin() else {
            reject(.busy, "The helper is checking power state; retry shortly.", reply: reply)
            return
        }
        queue.async {
            defer { self.admission.end() }
            var uid: uid_t = 0
            var gid: gid_t = 0
            _ = SCDynamicStoreCopyConsoleUser(nil, &uid, &gid)
            guard endpoint.isOpen, uid == endpoint.userID else {
                self.reject(.unauthorized, "The active login session changed.", reply: reply)
                return
            }
            guard let request = try? WireRequest.decode(payload) else {
                self.reject(.invalidRequest, "The request is invalid or unsupported.", reply: reply)
                return
            }
            #if LIDPILOT_PROFILE
            PerformanceTrace.event("xpc", fields: ["direction": "receive", "op": request.operation.rawValue, "session_id": request.sessionID.uuidString])
            #endif
            let result = self.engine.handle(request, client: endpoint.id)
            reply((try? result.encoded()) ?? Data())
        }
    }

    fileprivate func reject(_ code: WireFailureCode, _ message: String,
                            reply: @escaping @Sendable (Data) -> Void) {
        #if LIDPILOT_PROFILE
        PerformanceTrace.event("xpc", fields: ["direction": "reject", "code": String(describing: code)])
        #endif
        let result = WireReply(helperBuild: engine.build, message: message, failureCode: code)
        reply((try? result.encoded()) ?? Data())
    }

    fileprivate func disconnect(_ client: UUID) {
        queue.async { self.engine.disconnected(client: client) }
    }
}

private final class HelperEndpoint: NSObject, HelperXPCProtocol, @unchecked Sendable {
    let id = UUID()
    let userID: uid_t
    private let lock = NSLock()
    private var open = true
    private weak var service: HelperService?
    init(service: HelperService, userID: uid_t) { self.service = service; self.userID = userID }
    var isOpen: Bool { lock.lock(); defer { lock.unlock() }; return open }
    func close() {
        lock.lock()
        let wasOpen = open
        open = false
        lock.unlock()
        if wasOpen { service?.disconnect(id) }
    }
    func exchange(_ payload: Data, reply: @escaping @Sendable (Data) -> Void) {
        guard let service else {
            let result = WireReply(helperBuild: "unavailable", message: "Helper unavailable.", failureCode: .unavailable)
            reply((try? result.encoded()) ?? Data()); return
        }
        guard isOpen, payload.count <= WireRequest.maximumEncodedSize else {
            service.reject(.invalidRequest, "The connection or request is invalid.", reply: reply); return
        }
        service.submit(payload, endpoint: self, reply: reply)
    }
}
