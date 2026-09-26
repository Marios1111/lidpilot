import Foundation
import Testing
import LidPilotCore
@testable import LidPilotRuntime

struct HelperTransportTests {
    @Test func onlyExactProductionAndDevelopmentPairsResolve() throws {
        guard let production = HelperIdentity.configuration(
            appIdentifier: HelperIdentity.appID,
            helperIdentifier: HelperIdentity.helperID
        ), let development = HelperIdentity.configuration(
            appIdentifier: HelperIdentity.developmentAppID,
            helperIdentifier: HelperIdentity.developmentHelperID
        ) else {
            Issue.record("a supported LidPilot identity pair did not resolve")
            return
        }

        #expect(production.isProduction)
        #expect(production.appIdentifier == "com.lidpilot.app")
        #expect(production.helperIdentifier == "com.lidpilot.app.helper")
        #expect(production.serviceIdentifier == "com.lidpilot.app.helper")
        #expect(production.daemonLabel == "com.lidpilot.app.helper")
        #expect(production.daemonPlistName == "com.lidpilot.app.helper.plist")
        #expect(production.userStateDirectoryName == "LidPilot")
        #expect(production.recoveryDirectory == "/Library/Application Support/LidPilot")
        #expect(production.commandFenceDirectory == "/Library/Application Support/LidPilot")
        #expect(development.appIdentifier == "com.lidpilot.app.dev")
        #expect(development.helperIdentifier == "com.lidpilot.app.dev.helper")
        #expect(development.serviceIdentifier == "com.lidpilot.app.dev.helper")
        #expect(development.daemonLabel == "com.lidpilot.app.dev.helper")
        #expect(development.daemonPlistName == "com.lidpilot.app.dev.helper.plist")
        #expect(development.userStateDirectoryName == "LidPilot Development")
        #expect(development.recoveryDirectory == "/Library/Application Support/LidPilot Development")
        #expect(development.commandFenceDirectory == production.commandFenceDirectory)
        #expect(!development.isProduction)
    }

    @Test func mismatchedAndUnknownIdentitiesFailClosed() {
        #expect(HelperIdentity.configuration(appIdentifier: "other.app", helperIdentifier: HelperIdentity.helperID) == nil)
        #expect(HelperIdentity.configuration(appIdentifier: HelperIdentity.appID, helperIdentifier: HelperIdentity.developmentHelperID) == nil)
        #expect(HelperIdentity.configuration(appIdentifier: HelperIdentity.developmentAppID, helperIdentifier: HelperIdentity.helperID) == nil)
        #expect(HelperIdentity.configuration(appIdentifier: nil, helperIdentifier: HelperIdentity.helperID) == nil)
        #expect(HelperIdentity.configuration(appIdentifier: HelperIdentity.appID, helperIdentifier: nil) == nil)
    }

    @Test func signingRequirementsRemainPairedAndRejectInvalidTeams() throws {
        guard let production = HelperIdentity.configuration(
            appIdentifier: HelperIdentity.appID,
            helperIdentifier: HelperIdentity.helperID
        ), let development = HelperIdentity.configuration(
            appIdentifier: HelperIdentity.developmentAppID,
            helperIdentifier: HelperIdentity.developmentHelperID
        ) else {
            Issue.record("a supported LidPilot identity pair did not resolve")
            return
        }

        let productionAppRequirement = try HelperIdentity.applicationRequirement(for: production, team: "ABCDEFGHIJ")
        let developmentAppRequirement = try HelperIdentity.applicationRequirement(for: development, team: "ABCDEFGHIJ")
        let productionHelperRequirement = try HelperIdentity.helperRequirement(for: production, team: "ABCDEFGHIJ")
        let developmentHelperRequirement = try HelperIdentity.helperRequirement(for: development, team: "ABCDEFGHIJ")
        #expect(productionAppRequirement.contains("identifier \"com.lidpilot.app\""))
        #expect(developmentAppRequirement.contains("identifier \"com.lidpilot.app.dev\""))
        #expect(productionHelperRequirement.contains("identifier \"com.lidpilot.app.helper\""))
        #expect(developmentHelperRequirement.contains("identifier \"com.lidpilot.app.dev.helper\""))
        #expect(productionHelperRequirement.contains("certificate leaf[subject.OU] = \"ABCDEFGHIJ\""))
        #expect(throws: (any Error).self) {
            try HelperIdentity.applicationRequirement(for: production, team: "\" or true")
        }
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
