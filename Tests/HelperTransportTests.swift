import Foundation
import Testing
import LidPilotCore
@testable import LidPilotRuntime

struct HelperTransportTests {
    @Test func signingRequirementRejectsInjectedOrMissingIdentity() throws {
        #expect(throws: (any Error).self) { try HelperIdentity.requirement(identifier: "other.app", team: "ABCDEFGHIJ") }
        #expect(throws: (any Error).self) { try HelperIdentity.requirement(identifier: HelperIdentity.appID, team: "\" or true") }
        #expect(try HelperIdentity.requirement(identifier: HelperIdentity.appID, team: "ABCDEFGHIJ").contains("anchor apple generic"))
    }

}

struct HelperAdmissionTests {
    @Test func blockedRequestCannotAccumulateClientBacklog() {
        let admission = HelperAdmission()
        #expect(admission.begin())
        for _ in 0..<1000 { #expect(!admission.begin()) }
        admission.end()
        #expect(admission.begin())
        admission.end()
    }

    @Test func errorsRemainBoundedTypedWireReplies() throws {
        for code in [WireFailureCode.busy, .invalidRequest, .unauthorized, .unavailable] {
            let reply = WireReply(helperBuild: "1", message: "Request rejected.", failureCode: code)
            let data = try reply.encoded()
            let decoded = try WireReply.decode(data)
            #expect(decoded.failureCode == code && !decoded.success && decoded.flag == .unknown)
        }
    }
}
