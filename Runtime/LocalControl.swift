import Foundation
import Darwin
import LidPilotCore

public enum ControlOperation: String, Codable, Sendable {
    case status, start, stop, diagnostics, taskStart, taskEvent, arm, disarm, hook
}

public enum ControlCode: Int, Codable, Sendable {
    case success = 0, invalidInput = 64, unavailable = 69, conflict = 73, unverified = 75, approvalRequired = 77, blocked = 78
}

/// Only user-level intentions cross this boundary. Paths, commands and raw hook
/// payloads never reach the GUI or privileged helper.
public struct ControlRequest: Codable, Sendable {
    public var schemaVersion = 1
    public var operation: ControlOperation
    public var mode: Mode?
    public var seconds: Double?
    public var event: WorkloadEvent?
    public var hook: HookSignal?
    public var sentAt = Date()

    public init(_ operation: ControlOperation, mode: Mode? = nil, seconds: Double? = nil,
                event: WorkloadEvent? = nil, hook: HookSignal? = nil) {
        self.operation = operation; self.mode = mode; self.seconds = seconds
        self.event = event; self.hook = hook
    }

    public func validate(now: Date = Date()) throws {
        guard schemaVersion == 1, sentAt.timeIntervalSinceReferenceDate.isFinite,
              (-5...60).contains(now.timeIntervalSince(sentAt)) else { throw ControlError.invalid }
        switch operation {
        case .start:
            guard mode != nil, let seconds, seconds.isFinite, (1...604_800).contains(seconds), event == nil, hook == nil else { throw ControlError.invalid }
        case .taskStart, .taskEvent:
            guard mode != nil, event?.source == .command, hook == nil else { throw ControlError.invalid }
            if let seconds {
                guard operation == .taskStart, seconds.isFinite, (60...86_400).contains(seconds) else { throw ControlError.invalid }
            }
            if operation == .taskStart, event?.state != .working { throw ControlError.invalid }
        case .hook:
            guard let hook, event == nil, seconds == nil, mode == nil else { throw ControlError.invalid }
            try hook.validate()
        default:
            guard mode == nil, seconds == nil, event == nil, hook == nil else { throw ControlError.invalid }
        }
    }
}

public struct ControlStatus: Codable, Sendable {
    public let schemaVersion: Int
    public let appVersion: String
    public let appBuild: String
    public let generation: UInt64
    public let phase: SessionPhase
    public let requestedMode: Mode?
    public let effectiveMode: Mode?
    public let manualMode: Mode?
    public let manualDeadline: SessionDeadline?
    public let observed: PowerSnapshot?
    public let systemAssertion: FlagState
    public let displayAssertion: FlagState
    public let helper: WireReply?
    public let message: String
    public let lastConfirmedOperation: String?
    public let nextStep: String
    public let integrationsArmed: Bool
    public let workloads: [WorkloadRecord]
    public let sampledAt: Date

    @MainActor public init(controller: SessionController) {
        schemaVersion = 1; generation = controller.generation; phase = controller.phase
        appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        requestedMode = controller.requestedMode; effectiveMode = controller.effectiveMode
        manualMode = controller.manualMode; manualDeadline = controller.manualDeadline
        observed = controller.observation; helper = controller.helperState
        systemAssertion = controller.assertions.system; displayAssertion = controller.assertions.display
        message = controller.message; lastConfirmedOperation = controller.lastConfirmedOperation
        integrationsArmed = controller.integrationsArmed; workloads = controller.workloads.records
        sampledAt = Date()
        switch controller.phase {
        case .off: nextStep = controller.integrationsArmed
            ? "Hooks are armed. Turn Off disarms them; a new task can request protection."
            : "No request is active. Start a session when you need protection."
        case .recovery: nextStep = "Keep the lid open and use Settings → Helper & Recovery."
        case .paused: nextStep = "Resolve the pause, then explicitly start or re-arm tasks."
        case .unverified: nextStep = "Refresh helper status in Settings."
        case .updating: nextStep = "Finish the update with the lid open."
        default: nextStep = "Use Turn Off to release every LidPilot request."
        }
    }
}

public struct ControlReply: Codable, Sendable {
    public var schemaVersion = 1
    public var code: ControlCode
    public var message: String
    public var status: ControlStatus?
    public var diagnostics: [DiagnosticEntry]?
    public init(code: ControlCode, message: String, status: ControlStatus? = nil, diagnostics: [DiagnosticEntry]? = nil) {
        self.code = code; self.message = message; self.status = status; self.diagnostics = diagnostics
    }
    public func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

public enum ControlError: Error, LocalizedError, Equatable {
    case invalid, unavailable, unsafePath, busy, oversized, timedOut
    public var errorDescription: String? {
        switch self {
        case .invalid: "Invalid or expired control request."
        case .unavailable: "Open LidPilot and connect your agent in Settings → Agent Tasks, or enable CLI control in Settings → Command Line."
        case .unsafePath: "The local control endpoint has unsafe ownership or permissions."
        case .busy: "Another LidPilot instance owns this control endpoint."
        case .oversized: "The local control message exceeds its size limit."
        case .timedOut: "The app did not confirm this operation in time. Check its status before retrying."
        }
    }
}

public enum LocalControl {
    public static let maximumFrame = 256 * 1024
    public static func path(channel: String) -> String {
        "/private/tmp/lidpilot-control-\(getuid())/\(channel).sock"
    }

    static func directory(for path: String, create: Bool) throws {
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
        if create, mkdir(parent, 0o700) != 0, errno != EEXIST { throw ControlError.unsafePath }
        var info = stat()
        guard lstat(parent, &info) == 0 else { throw create ? ControlError.unsafePath : ControlError.unavailable }
        guard info.st_mode & S_IFMT == S_IFDIR,
              info.st_uid == getuid(), info.st_mode & 0o777 == 0o700 else { throw ControlError.unsafePath }
    }

    static func address(_ path: String) throws -> sockaddr_un {
        var value = sockaddr_un()
        guard path.utf8.count < MemoryLayout.size(ofValue: value.sun_path) else { throw ControlError.unsafePath }
        value.sun_family = sa_family_t(AF_UNIX)
        value.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &value.sun_path) { bytes in
            bytes.initializeMemory(as: UInt8.self, repeating: 0)
            bytes.copyBytes(from: Array(path.utf8))
        }
        return value
    }

    static func configure(_ fd: Int32, timeout: Double) {
        var value: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &value, socklen_t(MemoryLayout<Int32>.size))
        var limit = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - floor(timeout)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &limit, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &limit, socklen_t(MemoryLayout<timeval>.size))
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
    }

    static func authenticate(_ fd: Int32) throws {
        var uid: uid_t = 0; var gid: gid_t = 0
        guard getpeereid(fd, &uid, &gid) == 0, uid == getuid(), uid != 0 else { throw ControlError.unsafePath }
    }

    static func wait(_ fd: Int32, event: Int32, until deadline: Double) throws {
        while true {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw ControlError.timedOut }
            var descriptor = pollfd(fd: fd, events: Int16(event), revents: 0)
            let result = poll(&descriptor, 1, Int32(min(remaining * 1000 + 1, Double(Int32.max))))
            if result < 0, errno == EINTR { continue }
            guard result > 0 else { throw ControlError.timedOut }
            return
        }
    }

    static func read(_ fd: Int32, count: Int, until deadline: Double) throws -> Data {
        var result = Data(count: count)
        try result.withUnsafeMutableBytes { bytes in
            var position = 0
            while position < count {
                try wait(fd, event: POLLIN, until: deadline)
                let n = recv(fd, bytes.baseAddress!.advanced(by: position), count - position, MSG_DONTWAIT)
                if n < 0, errno == EINTR || errno == EAGAIN { continue }
                guard n > 0 else { throw ControlError.timedOut }
                position += n
            }
        }
        return result
    }

    static func readFrame(_ fd: Int32, maximum: Int = maximumFrame, timeout: Double = 2) throws -> Data {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        let header = try read(fd, count: 4, until: deadline)
        let length = header.reduce(0) { ($0 << 8) | Int($1) }
        guard length > 0, length <= maximum else { throw ControlError.oversized }
        return try read(fd, count: length, until: deadline)
    }

    static func writeFrame(_ data: Data, to fd: Int32, timeout: Double = 2) throws {
        guard !data.isEmpty, data.count <= maximumFrame else { throw ControlError.oversized }
        var length = UInt32(data.count).bigEndian
        let framed = withUnsafeBytes(of: &length) { Data($0) } + data
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        try framed.withUnsafeBytes { bytes in
            var position = 0
            while position < bytes.count {
                try wait(fd, event: POLLOUT, until: deadline)
                let n = Darwin.send(fd, bytes.baseAddress!.advanced(by: position), bytes.count - position, MSG_DONTWAIT)
                if n < 0, errno == EINTR || errno == EAGAIN { continue }
                guard n > 0 else { throw ControlError.timedOut }
                position += n
            }
        }
    }

    public static func send(_ request: ControlRequest, path: String, timeout: Double = 40) throws -> ControlReply {
        try directory(for: path, create: false)
        var info = stat()
        guard lstat(path, &info) == 0 else { throw ControlError.unavailable }
        guard info.st_mode & S_IFMT == S_IFSOCK, info.st_uid == getuid(), info.st_mode & 0o777 == 0o600 else { throw ControlError.unsafePath }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ControlError.unavailable }
        defer { close(fd) }
        configure(fd, timeout: timeout)
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        var addr = try address(path)
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        if connected != 0 {
            guard errno == EINPROGRESS else { throw ControlError.unavailable }
            try wait(fd, event: POLLOUT, until: ProcessInfo.processInfo.systemUptime + timeout)
            var error: Int32 = 0
            var size = socklen_t(MemoryLayout<Int32>.size)
            guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &size) == 0, error == 0 else { throw ControlError.unavailable }
        }
        try authenticate(fd)
        try writeFrame(JSONEncoder().encode(request), to: fd, timeout: timeout)
        return try JSONDecoder().decode(ControlReply.self, from: readFrame(fd, timeout: timeout))
    }
}

/// The accept queue owns socket lifetime/admission. At most eight requests are
/// outstanding, leaving room for Stop while an activation awaits the helper.
public final class LocalControlServer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.lidpilot.control")
    private var source: DispatchSourceRead?
    private var listener: Int32 = -1
    private var active = 0
    private var socketPath: String?
    private var inode: ino_t = 0
    private let handler: @Sendable (ControlRequest) async -> ControlReply

    public init(handler: @escaping @Sendable (ControlRequest) async -> ControlReply) { self.handler = handler }

    public func start(path: String) throws {
        try queue.sync {
            guard listener == -1 else { return }
            guard getuid() != 0 else { throw ControlError.unsafePath }
            try LocalControl.directory(for: path, create: true)
            var info = stat()
            if lstat(path, &info) == 0 {
                guard info.st_mode & S_IFMT == S_IFSOCK, info.st_uid == getuid(), info.st_mode & 0o777 == 0o600 else { throw ControlError.unsafePath }
                let probe = socket(AF_UNIX, SOCK_STREAM, 0)
                guard probe >= 0 else { throw ControlError.unavailable }
                _ = fcntl(probe, F_SETFL, O_NONBLOCK)
                var addr = try LocalControl.address(path)
                let result = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(probe, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
                let code = errno
                close(probe)
                guard result != 0, code == ECONNREFUSED else { throw ControlError.busy }
                guard unlink(path) == 0 else { throw ControlError.unsafePath }
            }
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { throw ControlError.unavailable }
            var success = false
            defer { if !success { close(fd) } }
            var addr = try LocalControl.address(path)
            let result = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } }
            guard result == 0 else { throw ControlError.busy }
            guard chmod(path, 0o600) == 0, listen(fd, 8) == 0, lstat(path, &info) == 0 else { unlink(path); throw ControlError.unavailable }
            LocalControl.configure(fd, timeout: 2)
            _ = fcntl(fd, F_SETFL, O_NONBLOCK)
            listener = fd; socketPath = path; inode = info.st_ino
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            source.setEventHandler { [weak self] in self?.acceptAvailable() }
            source.setCancelHandler { close(fd) }
            self.source = source
            success = true
            source.resume()
        }
    }

    public func stop() {
        queue.sync {
            source?.cancel(); source = nil; listener = -1
            if let path = socketPath {
                var info = stat()
                if lstat(path, &info) == 0, info.st_ino == inode { unlink(path) }
            }
            socketPath = nil
        }
    }

    private func acceptAvailable() {
        while listener >= 0 {
            let fd = accept(listener, nil, nil)
            guard fd >= 0 else { return }
            guard active < 8 else { close(fd); continue }
            active += 1
            LocalControl.configure(fd, timeout: 2)
            let handler = self.handler
            Task.detached { [weak self] in
                defer { close(fd); self?.queue.async { [weak self] in self?.active -= 1 } }
                do {
                    try LocalControl.authenticate(fd)
                    let request = try JSONDecoder().decode(ControlRequest.self, from: LocalControl.readFrame(fd, maximum: 16 * 1024))
                    try request.validate()
                    let reply = await handler(request)
                    try LocalControl.writeFrame(JSONEncoder().encode(reply), to: fd)
                } catch {
                    let reply = ControlReply(code: .invalidInput, message: "Invalid local control request.")
                    if let data = try? JSONEncoder().encode(reply) { try? LocalControl.writeFrame(data, to: fd) }
                }
            }
        }
    }
}
