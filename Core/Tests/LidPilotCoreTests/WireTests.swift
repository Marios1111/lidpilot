import Foundation
import XCTest
@testable import LidPilotCore

final class WireTests: CoreTestCase {
    func testWireRequestRoundTripsAClosedLidAcquireWithBoundedCodec() throws {
        let deadline = try SessionDeadline(duration: .seconds(60), clock: clock(continuous: 100))
        let request = WireRequest(
            operation: .acquire,
            sessionID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            generation: 1,
            deadline: deadline,
            policy: SafetyPolicy(),
            mode: .closed
        )

        let encoded = try WireRequest.encode(request)
        XCTAssertLessThanOrEqual(encoded.count, WireRequest.maximumEncodedSize)
        let decoded = try WireRequest.decode(encoded)
        XCTAssertEqual(decoded, request)
    }

    func testWireRequestRejectsDisplayAcquireAndMissingPayloads() throws {
        let id = UUID()
        let base = WireRequest(operation: .acquire, sessionID: id, generation: 1)
        XCTAssertThrowsError(try base.validate())

        let display = WireRequest(operation: .acquire, sessionID: id, generation: 1, deadline: try deadline(), policy: SafetyPolicy(), mode: .display)
        XCTAssertThrowsError(try display.validate())

        let renew = WireRequest(operation: .renew, sessionID: id, generation: 1, policy: SafetyPolicy(), mode: .closed)
        XCTAssertThrowsError(try renew.validate())

        let inspectWithPayload = WireRequest(operation: .inspect, sessionID: id, generation: 1, mode: .closed)
        XCTAssertThrowsError(try inspectWithPayload.validate())
    }

    func testWireRequestRejectsGenerationProtocolAndInvalidPolicy() throws {
        let deadline = try self.deadline()
        let id = UUID()
        let valid = WireRequest(operation: .acquire, sessionID: id, generation: 1, deadline: deadline, policy: SafetyPolicy(), mode: .smart)

        var zeroGeneration = valid
        zeroGeneration.generation = 0
        XCTAssertThrowsError(try zeroGeneration.validate())

        var wrongProtocol = valid
        wrongProtocol.protocolVersion = 2
        XCTAssertThrowsError(try wrongProtocol.validate())

        var invalidPolicy = valid
        invalidPolicy.policy = SafetyPolicy(batteryFloor: 25)
        XCTAssertThrowsError(try invalidPolicy.validate())
    }

    func testWireCodecRejectsMalformedAndOversizedData() throws {
        XCTAssertThrowsError(try WireRequest.decode(Data("not-json".utf8)))
        XCTAssertThrowsError(try WireReply.decode(Data(repeating: 0x20, count: WireReply.maximumEncodedSize + 1)))

        let reply = WireReply(helperBuild: String(repeating: "x", count: WireReply.maximumEncodedSize))
        XCTAssertThrowsError(try WireReply.encode(reply))
    }

    func testWireReplyRoundTripsHealthSample() throws {
        let reply = WireReply(
            helperBuild: "1.0.0",
            flag: .on,
            ownsOverride: true,
            recoveryPending: false,
            leaseActive: true,
            message: "healthy",
            success: true,
            sample: snapshot(sleepDisabled: .on),
            health: HelperHealth(journalHealthy: true, powerStateReadable: true, watchdogAvailable: true)
        )

        let decoded = try WireReply.decode(try WireReply.encode(reply))
        XCTAssertEqual(decoded, reply)
    }

    func testTypedErrorRoundTripsWithoutInventingObservedState() throws {
        let reply = WireReply(helperBuild: "1", message: "Busy", failureCode: .busy)
        let decoded = try WireReply.decode(reply.encoded())
        XCTAssertEqual(decoded.failureCode, .busy)
        XCTAssertEqual(decoded.flag, .unknown)
        XCTAssertFalse(decoded.success)
        XCTAssertNil(decoded.health)
    }

    private func deadline() throws -> SessionDeadline {
        try SessionDeadline(duration: .seconds(60), clock: clock(continuous: 100))
    }
}
