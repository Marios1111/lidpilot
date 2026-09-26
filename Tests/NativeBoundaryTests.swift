import Foundation
import Darwin
import Testing
@testable import LidPilotRuntime

struct NativeBoundaryTests {
    @Test func powerOutputParserFailsClosed() {
        #expect(PMSetDriver.parse("System-wide power settings:\n SleepDisabled\t\t1\n") == .on)
        #expect(PMSetDriver.parse("SleepDisabled 0\n") == .off)
        for text in ["", "SleepDisabled 2", "SleepDisabled 1 extra", "SleepDisabled 0\nSleepDisabled 1"] {
            #expect(PMSetDriver.parse(text) == .unknown)
        }
    }

    @Test func journalPersistsRestrictiveRecordAndRejectsSymlink() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("lidpilot-journal-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let journal = try RecoveryJournal(directory: folder.path, owner: geteuid())
        #expect(try journal.load() == nil)
        let record = RecoveryRecord(sessionID: UUID(), generation: 1, bootID: "test")
        try journal.save(record)
        #expect(try journal.load() == record)
        var info = stat()
        #expect(lstat(folder.appendingPathComponent("recovery.json").path, &info) == 0)
        #expect(info.st_mode & 0o777 == 0o600)
        try journal.clear()
        let target = folder.appendingPathComponent("untouched")
        try Data("unrelated".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("recovery.json"), withDestinationURL: target)
        #expect(throws: (any Error).self) { try journal.load() }
        #expect(try String(contentsOf: target, encoding: .utf8) == "unrelated")
    }

    @Test func distinctJournalsShareOneCommandFence() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("lidpilot-isolated-journals-\(UUID())")
        let productionDirectory = root.appendingPathComponent("production", isDirectory: true)
        let developmentDirectory = root.appendingPathComponent("development", isDirectory: true)
        let fenceDirectory = root.appendingPathComponent("shared-fence", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: root) }

        let production = try RecoveryJournal(directory: productionDirectory.path,
                                             commandFenceDirectory: fenceDirectory.path, owner: geteuid())
        let development = try RecoveryJournal(directory: developmentDirectory.path,
                                              commandFenceDirectory: fenceDirectory.path, owner: geteuid())
        let productionRecord = RecoveryRecord(sessionID: UUID(), generation: 1, bootID: "prod")
        let developmentRecord = RecoveryRecord(sessionID: UUID(), generation: 1, bootID: "dev")
        try production.save(productionRecord)
        try development.save(developmentRecord)
        #expect(try production.load() == productionRecord)
        #expect(try development.load() == developmentRecord)
        #expect(productionDirectory.appendingPathComponent("recovery.json") !=
                developmentDirectory.appendingPathComponent("recovery.json"))

        let productionDriver = try production.makePowerDriver()
        let developmentDriver = try development.makePowerDriver()
        try productionDriver.withMutationFence {}
        try developmentDriver.withMutationFence {}

        let fenceDescriptor = open(fenceDirectory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        #expect(fenceDescriptor >= 0)
        defer { if fenceDescriptor >= 0 { close(fenceDescriptor) } }
        let first = try CommandFence(directoryDescriptor: fenceDescriptor, owner: geteuid())
        let second = try CommandFence(directoryDescriptor: fenceDescriptor, owner: geteuid())
        var secondWasBlocked = false
        try first.withExclusive {
            do {
                try second.withExclusive(timeout: 0) {}
            } catch {
                secondWasBlocked = true
            }
            #expect(secondWasBlocked)
        }
        try second.withExclusive(timeout: 0) {}
    }

    @Test func journalRejectsLooseDirectoryPermissions() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("lidpilot-permissions-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        chmod(folder.path, 0o755)
        do {
            _ = try RecoveryJournal(directory: folder.path, owner: geteuid())
            Issue.record("a loosely permissioned recovery directory was accepted")
        } catch let error as RuntimeFailure {
            #expect(error == .unavailable("Recovery directory ownership or permissions are unsafe."))
        } catch {
            Issue.record("unexpected recovery-directory error: \(error)")
        }
    }

    @Test func privilegedJournalRejectsTheUnknownTestBundleIdentity() {
        #expect(throws: (any Error).self) { try RecoveryJournal.privileged() }
    }
}
