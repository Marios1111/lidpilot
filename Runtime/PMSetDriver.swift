import Foundation
import Darwin
import LidPilotCore

public enum RuntimeFailure: Error, LocalizedError, Equatable {
    case unavailable(String)
    public var errorDescription: String? {
        switch self { case .unavailable(let message): return message }
    }
}

public protocol SleepFlagControlling: Sendable {
    func read() throws -> FlagState
    func setDisabled(_ disabled: Bool) throws
}

/// There is deliberately no executable, argument, environment, or path parameter in this API.
public struct PMSetDriver: SleepFlagControlling {
    public init() {}

    public func read() throws -> FlagState { Self.parse(try run(["-g"])) }

    public func setDisabled(_ disabled: Bool) throws {
        guard geteuid() == 0 else { throw RuntimeFailure.unavailable("The approved helper is required.") }
        _ = try run(["-a", "disablesleep", disabled ? "1" : "0"])
    }

    public static func parse(_ output: String) -> FlagState {
        let values = output.split(separator: "\n").compactMap { line -> String? in
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.first == "SleepDisabled", fields.count == 2 else { return nil }
            return String(fields[1])
        }
        guard values.count == 1 else { return .unknown }
        switch values[0] { case "0": return .off; case "1": return .on; default: return .unknown }
    }

    private func run(_ arguments: [String]) throws -> String {
        let child = Process()
        let output = Pipe()
        let completed = DispatchSemaphore(value: 0)
        child.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        child.arguments = arguments
        child.environment = ["PATH": "/usr/bin:/bin", "LANG": "C", "LC_ALL": "C"]
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = output
        child.standardError = output
        child.terminationHandler = { _ in completed.signal() }
        try child.run()
        let timedOut = completed.wait(timeout: .now() + 5) == .timedOut
        if timedOut {
            // Kill and reap before another mutation can start. No orphan enable may race restoration.
            if child.isRunning { kill(child.processIdentifier, SIGKILL) }
            child.waitUntilExit()
        }
        try? output.fileHandleForWriting.close()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        try? output.fileHandleForReading.close()
        guard !timedOut else { throw RuntimeFailure.unavailable("Power command timed out; recovery is required.") }
        guard child.terminationStatus == 0, data.count <= 16_384 else {
            throw RuntimeFailure.unavailable("Power command failed (status \(child.terminationStatus)).")
        }
        return String(decoding: data, as: UTF8.self)
    }
}
