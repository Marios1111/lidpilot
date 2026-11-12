import CoreGraphics
import Foundation
import Testing
@testable import LidPilotRuntime

@MainActor private final class BrightnessBackendStub: DisplayBrightnessBackend {
    var displays = [BrightnessDisplay(id: 1, uuid: UUID())]
    var value: Float = 0.7
    var writes: [Float] = []
    var failGet = false
    var failSet = false
    var ignoreSet = false
    var afterSet: (() -> Void)?
    func builtInDisplays() throws -> [BrightnessDisplay] { displays }
    func get(_ display: BrightnessDisplay) throws -> Float {
        if failGet { throw RuntimeFailure.unavailable("read failed") }
        return value
    }
    func set(_ value: Float, on display: BrightnessDisplay) throws {
        writes.append(value)
        if failSet { throw RuntimeFailure.unavailable("write failed") }
        if !ignoreSet { self.value = value }
        afterSet?()
    }
}

@MainActor private final class BrightnessJournalStub: BrightnessRecoveryStoring {
    var record: BrightnessRecovery?
    var failSave = false
    func load() throws -> BrightnessRecovery? { record }
    func save(_ record: BrightnessRecovery) throws {
        if failSave { throw RuntimeFailure.unavailable("save failed") }
        self.record = record
    }
    func clear() throws { record = nil }
}

@MainActor struct DisplayBrightnessTests {
    @Test func cachedOfflineTargetRequiresUnchangedBuiltInIdentity() {
        var cache = BrightnessTargetCache()
        let original = BrightnessDisplay(id: 1, uuid: UUID())
        #expect(cache.resolve(online: [original], isStillBuiltIn: { $0 == original }) == [original])
        #expect(cache.resolve(online: [], isStillBuiltIn: { $0 == original }) == [original])
        // The same numeric ID now belongs to an external display or a different UUID.
        #expect(cache.resolve(online: [], isStillBuiltIn: { _ in false }).isEmpty)
        #expect(cache.resolve(online: [], isStillBuiltIn: { _ in true }).isEmpty)
    }

    @Test func reconnectedDisplayReplacesCachedNumericIDWithoutAmbiguity() {
        var cache = BrightnessTargetCache()
        let old = BrightnessDisplay(id: 1, uuid: UUID())
        let replacement = BrightnessDisplay(id: 1, uuid: UUID())
        _ = cache.resolve(online: [old], isStillBuiltIn: { _ in true })
        #expect(cache.resolve(online: [replacement], isStillBuiltIn: { $0 == replacement }) == [replacement])
    }

    @Test func dimPersistsBeforeWriteAndRestoresOnce() throws {
        let backend = BrightnessBackendStub(), journal = BrightnessJournalStub()
        let controller = NativeDisplayBrightness(backend: backend, journal: journal)
        backend.afterSet = { #expect(journal.record?.original == 0.7) }
        try controller.setDimmed(true)
        try controller.setDimmed(true)
        #expect(backend.writes == [0])
        #expect(backend.value == 0)
        try controller.setDimmed(false)
        try controller.setDimmed(false)
        #expect(backend.writes == [0, 0.7])
        #expect(journal.record == nil)
    }

    @Test func respectsUserAdjustmentAndDoesNotRedimOnHeartbeat() throws {
        let backend = BrightnessBackendStub(), journal = BrightnessJournalStub()
        let controller = NativeDisplayBrightness(backend: backend, journal: journal)
        try controller.setDimmed(true)
        backend.value = 0.3
        try controller.setDimmed(true)
        try controller.setDimmed(false)
        #expect(backend.writes == [0])
        #expect(backend.value == 0.3)
        #expect(journal.record == nil)
    }

    @Test func originallyZeroRemainsZeroAfterRecovery() throws {
        let backend = BrightnessBackendStub(), journal = BrightnessJournalStub()
        backend.value = 0
        let controller = NativeDisplayBrightness(backend: backend, journal: journal)
        try controller.setDimmed(true)
        #expect(journal.record?.original == 0)
        try controller.setDimmed(false)
        #expect(backend.value == 0)
        #expect(journal.record == nil)
    }

    @Test func failedSaveDoesNotWrite() {
        let backend = BrightnessBackendStub(), journal = BrightnessJournalStub()
        journal.failSave = true
        let controller = NativeDisplayBrightness(backend: backend, journal: journal)
        #expect(throws: (any Error).self) { try controller.setDimmed(true) }
        #expect(backend.writes.isEmpty)
    }

    @Test func failedDimWriteAndReadbackRemainRecoverable() throws {
        for failWrite in [true, false] {
            let backend = BrightnessBackendStub(), journal = BrightnessJournalStub()
            let controller = NativeDisplayBrightness(backend: backend, journal: journal)
            backend.failSet = failWrite
            if !failWrite { backend.afterSet = { backend.failGet = true } }
            #expect(throws: (any Error).self) { try controller.setDimmed(true) }
            #expect(journal.record?.original == 0.7)
            #expect(throws: (any Error).self) { try controller.setDimmed(true) }
            #expect(backend.writes.count == 1)
            backend.failGet = false
            backend.failSet = false
            backend.afterSet = nil
            try controller.setDimmed(false)
            #expect(backend.value == 0.7)
            #expect(journal.record == nil)
        }
    }

    @Test func wrongDimReadbackThrows() {
        let backend = BrightnessBackendStub(), journal = BrightnessJournalStub()
        backend.ignoreSet = true
        let controller = NativeDisplayBrightness(backend: backend, journal: journal)
        #expect(throws: (any Error).self) { try controller.setDimmed(true) }
        #expect(journal.record != nil)
    }

    @Test func restoreFailureRetainsRecordAndCanRetry() throws {
        let backend = BrightnessBackendStub(), journal = BrightnessJournalStub()
        let controller = NativeDisplayBrightness(backend: backend, journal: journal)
        try controller.setDimmed(true)
        backend.failSet = true
        #expect(throws: (any Error).self) { try controller.setDimmed(false) }
        #expect(journal.record != nil)
        backend.failSet = false
        backend.ignoreSet = true
        #expect(throws: (any Error).self) { try controller.setDimmed(false) }
        #expect(journal.record != nil)
        backend.ignoreSet = false
        try controller.setDimmed(false)
        #expect(backend.value == 0.7)
        #expect(journal.record == nil)
    }

    @Test func invalidValuesAndAmbiguousDisplayNeverWrite() {
        for value: Float in [.nan, .infinity, -0.1, 1.1] {
            let backend = BrightnessBackendStub(), journal = BrightnessJournalStub()
            backend.value = value
            let controller = NativeDisplayBrightness(backend: backend, journal: journal)
            #expect(throws: (any Error).self) { try controller.setDimmed(true) }
            #expect(backend.writes.isEmpty)
            #expect(journal.record == nil)
        }
        for count in [0, 2] {
            let backend = BrightnessBackendStub(), journal = BrightnessJournalStub()
            backend.displays = (0..<count).map { BrightnessDisplay(id: UInt32($0), uuid: UUID()) }
            let controller = NativeDisplayBrightness(backend: backend, journal: journal)
            #expect(throws: (any Error).self) { try controller.setDimmed(true) }
            #expect(backend.writes.isEmpty)
        }
    }

    @Test func recoveryFollowsUUIDRatherThanReusedNumericID() throws {
        let backend = BrightnessBackendStub(), journal = BrightnessJournalStub()
        let controller = NativeDisplayBrightness(backend: backend, journal: journal)
        let uuid = backend.displays[0].uuid
        try controller.setDimmed(true)
        backend.displays = [BrightnessDisplay(id: 1, uuid: UUID())]
        #expect(throws: (any Error).self) { try controller.setDimmed(false) }
        #expect(journal.record != nil)
        #expect(backend.writes == [0])
        backend.displays = [BrightnessDisplay(id: 9, uuid: uuid)]
        try controller.setDimmed(false)
        #expect(backend.value == 0.7)
    }

    @Test func durableRecoveryWorksAcrossInstances() throws {
        let suite = "LidPilotTests.brightness.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let backend = BrightnessBackendStub()
        let first = NativeDisplayBrightness(backend: backend, journal: DefaultsBrightnessRecovery(defaults: defaults))
        try first.setDimmed(true)
        let secondDefaults = try #require(UserDefaults(suiteName: suite))
        let second = NativeDisplayBrightness(backend: backend, journal: DefaultsBrightnessRecovery(defaults: secondDefaults))
        #expect(throws: (any Error).self) { try second.setDimmed(true) }
        try second.setDimmed(false)
        #expect(backend.writes == [0, 0.7])
        #expect(try DefaultsBrightnessRecovery(defaults: defaults).load() == nil)
    }
}
