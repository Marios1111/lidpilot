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
}
