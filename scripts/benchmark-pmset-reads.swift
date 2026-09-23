#!/usr/bin/env swift
// Read-only A/B benchmark; compile once, then run that binary as user and root.
import CryptoKit
import Darwin
import Foundation

private let command = "/usr/bin/pmset"
private let fixedEnv = ["PATH=/usr/bin:/bin", "LANG=C", "LC_ALL=C", "HOME=/var/empty"]
private let timeoutNS: UInt64 = 5_000_000_000
private let outputLimit = 16_384
private let maxReads = 60 // Includes warmups.

private struct Failure: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct CPU {
    let user: UInt64
    let system: UInt64
}

private struct Read: Codable {
    let wallNanoseconds: UInt64
    let childUserMicroseconds: UInt64
    let childSystemMicroseconds: UInt64
    let sleepDisabled: String
    let outputSHA256: String
}

private struct Report: Codable {
    let schemaVersion: Int
    let label: String
    let executable: String
    let arguments: [String]
    let realUID: UInt32
    let effectiveUID: UInt32
    let fixedEnvironment: [String]
    let perCommandTimeoutSeconds: Int
    let totalReadLimitIncludesWarmups: Bool
    let totalReadsRequested: Int
    let warmupReadsRequested: Int
    let measuredReadsRequested: Int
    let startedAtUnixSeconds: Double
    let endedAtUnixSeconds: Double
    let warmupReads: [Read]
    let measuredReads: [Read]
    let measuredChildUserMicroseconds: UInt64
    let measuredChildSystemMicroseconds: UInt64
    let measuredTotalWallNanoseconds: UInt64
    let notes: String
}

private func add(_ a: UInt64, _ b: UInt64, _ label: String) throws -> UInt64 {
    let (sum, overflow) = a.addingReportingOverflow(b)
    guard !overflow else { throw Failure(message: "Overflow in \(label) counter") }
    return sum
}

private func difference(_ a: UInt64, _ b: UInt64, _ label: String) throws -> UInt64 {
    guard a >= b else { throw Failure(message: "Nonmonotonic \(label) counter") }
    return a - b
}

private func childCPU() throws -> CPU {
    var r = rusage()
    guard getrusage(RUSAGE_CHILDREN, &r) == 0 else { throw Failure(message: "getrusage failed (errno \(errno))") }
    func micros(_ t: timeval) throws -> UInt64 {
        guard t.tv_sec >= 0, t.tv_usec >= 0, t.tv_usec < 1_000_000 else {
            throw Failure(message: "Invalid getrusage CPU counter")
        }
        let seconds = UInt64(t.tv_sec)
        guard seconds <= UInt64.max / 1_000_000 else { throw Failure(message: "Overflow in getrusage counter") }
        return try add(seconds * 1_000_000, UInt64(t.tv_usec), "getrusage")
    }
    return CPU(user: try micros(r.ru_utime), system: try micros(r.ru_stime))
}

private func parseFlag(_ data: Data) -> String {
    let values = String(decoding: data, as: UTF8.self).split(separator: "\n").compactMap { line -> String? in
        let fields = line.split(whereSeparator: \.isWhitespace)
        guard fields.first == "SleepDisabled", fields.count == 2 else { return nil }
        return String(fields[1])
    }
    guard values.count == 1 else { return "unknown" }
    switch values[0] {
    case "0": return "off"
    case "1": return "on"
    default: return "unknown"
    }
}

private func measuredRead() throws -> Read {
    let cpu0 = try childCPU()
    let start = DispatchTime.now().uptimeNanoseconds
    let output = try spawnAndCapture()
    let end = DispatchTime.now().uptimeNanoseconds
    let cpu1 = try childCPU()
    return Read(wallNanoseconds: try difference(end, start, "wall-time"),
                childUserMicroseconds: try difference(cpu1.user, cpu0.user, "child-user-CPU"),
                childSystemMicroseconds: try difference(cpu1.system, cpu0.system, "child-system-CPU"),
                sleepDisabled: parseFlag(output),
                outputSHA256: SHA256.hash(data: output).map { String(format: "%02x", $0) }.joined())
}

private func spawnAndCapture() throws -> Data {
    var fds = [Int32](repeating: -1, count: 2)
    guard pipe(&fds) == 0 else { throw Failure(message: "pipe failed (errno \(errno))") }
    defer { if fds[0] >= 0 { close(fds[0]) }; if fds[1] >= 0 { close(fds[1]) } }
    for fd in fds {
        let flags = fcntl(fd, F_GETFD)
        guard flags >= 0, fcntl(fd, F_SETFD, flags | FD_CLOEXEC) == 0 else {
            throw Failure(message: "fcntl close-on-exec failed (errno \(errno))")
        }
    }
    let flags = fcntl(fds[0], F_GETFL)
    guard flags >= 0, fcntl(fds[0], F_SETFL, flags | O_NONBLOCK) == 0 else {
        throw Failure(message: "fcntl nonblocking failed (errno \(errno))")
    }

    var actions: posix_spawn_file_actions_t? = nil
    guard posix_spawn_file_actions_init(&actions) == 0 else { throw Failure(message: "spawn file actions init failed") }
    defer { posix_spawn_file_actions_destroy(&actions) }
    let input = open("/dev/null", O_RDONLY | O_CLOEXEC)
    guard input >= 0 else { throw Failure(message: "open /dev/null failed (errno \(errno))") }
    defer { close(input) }
    var action = posix_spawn_file_actions_adddup2(&actions, fds[1], STDOUT_FILENO)
    if action == 0 { action = posix_spawn_file_actions_adddup2(&actions, fds[1], STDERR_FILENO) }
    if action == 0 { action = posix_spawn_file_actions_adddup2(&actions, input, STDIN_FILENO) }
    if action == 0 { action = posix_spawn_file_actions_addclose(&actions, fds[0]) }
    if action == 0 { action = posix_spawn_file_actions_addclose(&actions, fds[1]) }
    if action == 0 { action = posix_spawn_file_actions_addclose(&actions, input) }
    guard action == 0 else { throw Failure(message: "spawn file action failed (\(action))") }

    var pid: pid_t = 0
    let result = withCStringVector([command, "-g"]) { argv in
        withCStringVector(fixedEnv) { env in posix_spawn(&pid, command, &actions, nil, argv, env) }
    }
    guard result == 0 else { throw Failure(message: "posix_spawn failed (\(result))") }
    close(fds[1]); fds[1] = -1

    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNS
    var data = Data()
    var status: Int32 = 0
    var reaped = false
    var eof = false
    do {
        while !eof || !reaped {
            if !eof { try drain(fds[0], into: &data, eof: &eof) }
            if !reaped {
                let waited = waitpid(pid, &status, WNOHANG)
                if waited == pid { reaped = true }
                else if waited < 0 {
                    if errno == EINTR { continue }
                    if errno == ECHILD { reaped = true; throw Failure(message: "waitpid lost ownership of the child") }
                    throw Failure(message: "waitpid failed (errno \(errno))")
                }
            }
            if eof && reaped { break }
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline else { throw Failure(message: "pmset exceeded the 5-second command timeout") }
            var pfd = pollfd(fd: fds[0], events: Int16(POLLIN | POLLHUP), revents: 0)
            let waitMS = Int32(max(1, min(20, (deadline - now) / 1_000_000)))
            let polled = poll(&pfd, 1, waitMS)
            if polled < 0 && errno != EINTR { throw Failure(message: "poll failed (errno \(errno))") }
        }
    } catch {
        if !reaped { reapAfterKill(pid, status: &status) }
        throw error
    }
    guard status == 0 else { throw Failure(message: "pmset exited unsuccessfully") }
    return data
}

private func drain(_ fd: Int32, into data: inout Data, eof: inout Bool) throws {
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
        let n = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress!, $0.count) }
        if n > 0 {
            guard n <= outputLimit, data.count <= outputLimit - n else { throw Failure(message: "pmset output exceeded 16 KiB") }
            data.append(contentsOf: buffer.prefix(n))
        } else if n == 0 { eof = true; return }
        else if errno == EINTR { continue }
        else if errno == EAGAIN || errno == EWOULDBLOCK { return }
        else { throw Failure(message: "pipe read failed (errno \(errno))") }
    }
}

private func reapAfterKill(_ pid: pid_t, status: inout Int32) {
    while true {
        let result = waitpid(pid, &status, WNOHANG)
        if result == pid || (result < 0 && errno == ECHILD) { return }
        if result < 0 && errno == EINTR { continue }
        if result < 0 { return }
        break
    }
    if kill(pid, SIGKILL) != 0 && errno != ESRCH { return }
    let deadline = DispatchTime.now().uptimeNanoseconds + 250_000_000
    while DispatchTime.now().uptimeNanoseconds < deadline {
        let result = waitpid(pid, &status, WNOHANG)
        if result == pid || (result < 0 && errno == ECHILD) { return }
        if result < 0 && errno != EINTR { return }
        usleep(2_000)
    }
}

private func withCStringVector<T>(_ strings: [String], _ body: (UnsafePointer<UnsafeMutablePointer<CChar>?>) throws -> T) rethrows -> T {
    let allocated = strings.map { strdup($0)! }
    defer { allocated.forEach { free($0) } }
    let vector: [UnsafeMutablePointer<CChar>?] = allocated.map { Optional($0) } + [nil]
    return try vector.withUnsafeBufferPointer { try body($0.baseAddress!) }
}

private func parserSelfTest() throws {
    guard parseFlag(Data("SleepDisabled 1\n".utf8)) == "on",
          parseFlag(Data("SleepDisabled 0\n".utf8)) == "off",
          parseFlag(Data("SleepDisabled 2\n".utf8)) == "unknown",
          parseFlag(Data("SleepDisabled 0\nSleepDisabled 1\n".utf8)) == "unknown",
          parseFlag(Data("other\n".utf8)) == "unknown" else { throw Failure(message: "parser self-test failed") }
}

do {
    var args = Array(CommandLine.arguments.dropFirst())
    var total = 60, warmupCount = 5, label = "unspecified", selfTest = false
    while !args.isEmpty {
        let key = args.removeFirst()
        switch key {
        case "--total-reads": guard !args.isEmpty, let n = Int(args.removeFirst()) else { throw Failure(message: "invalid --total-reads") }; total = n
        case "--warmups": guard !args.isEmpty, let n = Int(args.removeFirst()) else { throw Failure(message: "invalid --warmups") }; warmupCount = n
        case "--label": guard !args.isEmpty else { throw Failure(message: "--label requires a value") }; label = args.removeFirst()
        case "--self-test": selfTest = true
        case "--help", "-h": throw Failure(message: "Usage: benchmark-pmset-reads [--total-reads 1...60] [--warmups 0...total-1] [--label TEXT] [--self-test]; JSON goes to stdout. Compile once and run the same binary as user and root.")
        default: throw Failure(message: "unknown option: \(key)")
        }
    }
    if selfTest { try parserSelfTest(); FileHandle.standardError.write(Data("parser self-test passed\n".utf8)); exit(0) }
    guard (1...maxReads).contains(total), (0..<total).contains(warmupCount), label.utf8.count <= 64 else {
        throw Failure(message: "total reads must be 1...60 (including warmups); warmups must be less than total; label max is 64 bytes")
    }
    let startedAt = Date().timeIntervalSince1970
    let warmups = try (0..<warmupCount).map { _ in try measuredRead() }
    let reads = try (warmupCount..<total).map { _ in try measuredRead() }
    let endedAt = Date().timeIntervalSince1970
    let userCPU = try reads.reduce(UInt64(0)) { try add($0, $1.childUserMicroseconds, "user CPU") }
    let systemCPU = try reads.reduce(UInt64(0)) { try add($0, $1.childSystemMicroseconds, "system CPU") }
    let wall = try reads.reduce(UInt64(0)) { try add($0, $1.wallNanoseconds, "wall time") }
    let report = Report(schemaVersion: 1, label: label, executable: command, arguments: ["-g"],
        realUID: UInt32(getuid()), effectiveUID: UInt32(geteuid()), fixedEnvironment: fixedEnv,
        perCommandTimeoutSeconds: 5, totalReadLimitIncludesWarmups: true,
        totalReadsRequested: total, warmupReadsRequested: warmupCount,
        measuredReadsRequested: total - warmupCount,
        startedAtUnixSeconds: startedAt, endedAtUnixSeconds: endedAt,
        warmupReads: warmups, measuredReads: reads, measuredChildUserMicroseconds: userCPU,
        measuredChildSystemMicroseconds: systemCPU, measuredTotalWallNanoseconds: wall,
        notes: "Read-only fixed /usr/bin/pmset -g via public posix_spawn; fixed environment; merged stdout/stderr pipe captured serially; every child waited/reaped. No shell or power writes. Output text is not recorded, only its SHA-256 and a strict SleepDisabled parse. Unknown is never treated as Off. Each command is bounded to 5 seconds; total invocations including warmups are capped at 60.")
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(report)); FileHandle.standardOutput.write(Data([10]))
} catch {
    FileHandle.standardError.write(Data("pmset benchmark failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
