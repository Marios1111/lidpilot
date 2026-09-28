import Foundation
import XCTest
@testable import LidPilotCore

final class WorkloadTests: CoreTestCase {
    private let baseWall = 1_700_000_000.0

    private func event(
        _ eventID: String,
        source: WorkloadSource = .codex,
        session: String = "session",
        turn: String = "turn",
        task: String? = nil,
        sequence: UInt64,
        state: WorkloadState,
        timestamp: Date? = nil,
        adapterVersion: String = "1.0",
        exitCode: Int? = nil
    ) -> WorkloadEvent {
        WorkloadEvent(
            eventID: eventID,
            source: source,
            adapterVersion: adapterVersion,
            sessionID: session,
            turnID: turn,
            taskID: task,
            sequence: sequence,
            timestamp: timestamp ?? Date(timeIntervalSince1970: baseWall),
            state: state,
            exitCode: exitCode
        )
    }

    func testOverlappingRequestsEndIndependentlyAndOldTurnCannotEndNewTurn() throws {
        var registry = WorkloadRegistry()
        let firstAt = clock(continuous: 100)
        XCTAssertTrue(try registry.apply(
            event("a-start", source: .codex, session: "s", turn: "old", sequence: 1, state: .working),
            mode: .closed,
            at: firstAt
        ))
        XCTAssertTrue(try registry.apply(
            event("b-start", source: .command, session: "build", turn: "main", sequence: 1, state: .working),
            mode: .smart,
            at: clock(continuous: 101)
        ))
        XCTAssertTrue(try registry.apply(
            event("new-start", source: .codex, session: "s", turn: "new", sequence: 1, state: .working),
            mode: .display,
            at: clock(continuous: 102)
        ))
        XCTAssertEqual(registry.activeHolds(at: clock(continuous: 102)).count, 3)

        XCTAssertTrue(try registry.apply(
            event("a-finish", source: .codex, session: "s", turn: "old", sequence: 2, state: .finished),
            mode: .closed,
            at: clock(continuous: 103)
        ))
        XCTAssertEqual(Set(registry.activeHolds(at: clock(continuous: 104)).map(\.mode)), Set([.smart, .display]))
        XCTAssertFalse(try registry.apply(
            event("late-old-finish", source: .codex, session: "s", turn: "old", sequence: 3, state: .finished),
            mode: .closed,
            at: clock(continuous: 105)
        ))
        XCTAssertTrue(registry.activeHolds(at: clock(continuous: 106)).contains { $0.mode == .display })
    }

    func testDuplicateAndOutOfOrderEventsAreIgnored() throws {
        var registry = WorkloadRegistry()
        let start = event("start", sequence: 1, state: .working)
        XCTAssertTrue(try registry.apply(start, mode: .closed, at: clock(continuous: 100)))
        XCTAssertFalse(try registry.apply(start, mode: .closed, at: clock(continuous: 101)))
        XCTAssertTrue(try registry.apply(
            event("later", sequence: 3, state: .working),
            mode: .closed,
            at: clock(continuous: 102)
        ))
        XCTAssertFalse(try registry.apply(
            event("out-of-order", sequence: 2, state: .finished),
            mode: .closed,
            at: clock(continuous: 103)
        ))
        XCTAssertEqual(registry.records.first?.state, .working)
        XCTAssertEqual(registry.activeHolds(at: clock(continuous: 104)).count, 1)
    }

    func testTerminalBeforeStartBlocksLaterStart() throws {
        var registry = WorkloadRegistry()
        XCTAssertTrue(try registry.apply(
            event("finish", sequence: 2, state: .finished),
            mode: .closed,
            at: clock(continuous: 100)
        ))
        XCTAssertFalse(try registry.apply(
            event("late-start", sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 101)
        ))
        XCTAssertTrue(registry.records.isEmpty)
        XCTAssertTrue(registry.activeHolds(at: clock(continuous: 102)).isEmpty)
    }

    func testParentCompletionDoesNotEndSubagentHold() throws {
        var registry = WorkloadRegistry()
        XCTAssertTrue(try registry.apply(
            event("parent-start", source: .claude, sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 100)
        ))
        XCTAssertTrue(try registry.apply(
            event("child-start", source: .claude, task: "worker-1", sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 101)
        ))
        XCTAssertTrue(try registry.apply(
            event("parent-finish", source: .claude, sequence: 2, state: .finished),
            mode: .closed,
            at: clock(continuous: 102)
        ))
        XCTAssertEqual(registry.activeHolds(at: clock(continuous: 103)).map(\.id), [
            registry.records.first(where: { $0.taskID == "worker-1" })!.id
        ])
    }

    func testRepeatedWaitingDoesNotResetGracePeriod() throws {
        var registry = WorkloadRegistry()
        let options = WorkloadOptions(waitingGrace: 30, staleAfter: 60, maximumDuration: 300)
        XCTAssertTrue(try registry.apply(
            event("start", sequence: 1, state: .working),
            mode: .closed,
            options: options,
            at: clock(continuous: 100)
        ))
        XCTAssertTrue(try registry.apply(
            event("wait-1", sequence: 2, state: .waiting),
            mode: .closed,
            options: options,
            at: clock(continuous: 110)
        ))
        let firstWaitingDeadline = try XCTUnwrap(registry.records.first?.holdDeadline)
        XCTAssertTrue(try registry.apply(
            event("wait-heartbeat", sequence: 3, state: .waiting),
            mode: .closed,
            options: options,
            at: clock(continuous: 130)
        ))
        XCTAssertEqual(registry.records.first?.holdDeadline, firstWaitingDeadline)
        XCTAssertEqual(registry.activeHolds(at: clock(continuous: 139)).count, 1)
        XCTAssertTrue(registry.activeHolds(at: clock(continuous: 140)).isEmpty)
    }

    func testIdleSettlesOnceAndWorkingContinuationKeepsOriginalHardDeadline() throws {
        var registry = WorkloadRegistry()
        let options = WorkloadOptions(settlingInterval: 3, staleAfter: 60, maximumDuration: 300)
        XCTAssertTrue(try registry.apply(
            event("start", sequence: 1, state: .working),
            mode: .closed,
            options: options,
            at: clock(continuous: 100)
        ))
        let originalHardDeadline = try XCTUnwrap(registry.records.first?.hardDeadline)
        XCTAssertTrue(try registry.apply(
            event("idle-1", sequence: 2, state: .idle),
            mode: .closed,
            options: options,
            at: clock(continuous: 101)
        ))
        let idleDeadline = try XCTUnwrap(registry.records.first?.holdDeadline)
        XCTAssertTrue(try registry.apply(
            event("idle-heartbeat", sequence: 3, state: .idle),
            mode: .closed,
            options: options,
            at: clock(continuous: 102)
        ))
        XCTAssertEqual(registry.records.first?.holdDeadline, idleDeadline)
        XCTAssertEqual(registry.activeHolds(at: clock(continuous: 103)).count, 1)
        XCTAssertTrue(registry.activeHolds(at: clock(continuous: 104)).isEmpty)

        XCTAssertTrue(try registry.apply(
            event("continued", sequence: 4, state: .working),
            mode: .closed,
            options: options,
            at: clock(continuous: 105)
        ))
        XCTAssertEqual(registry.records.first?.startedAt, clock(continuous: 100))
        XCTAssertEqual(registry.records.first?.hardDeadline, originalHardDeadline)
        XCTAssertEqual(registry.activeHolds(at: clock(continuous: 106)).count, 1)
    }

    func testStaleAndHardExpiryBecomeUnknown() throws {
        var staleRegistry = WorkloadRegistry()
        let staleOptions = WorkloadOptions(staleAfter: 60, maximumDuration: 300)
        XCTAssertTrue(try staleRegistry.apply(
            event("start", sequence: 1, state: .working),
            mode: .closed,
            options: staleOptions,
            at: clock(continuous: 100)
        ))
        staleRegistry.expire(at: clock(continuous: 160))
        XCTAssertEqual(staleRegistry.records.first?.state, .unknown)
        XCTAssertTrue(staleRegistry.activeHolds(at: clock(continuous: 160)).isEmpty)

        var hardExpiryRegistry = WorkloadRegistry()
        let hardOptions = WorkloadOptions(staleAfter: 1_800, maximumDuration: 60)
        XCTAssertTrue(try hardExpiryRegistry.apply(
            event("start", sequence: 1, state: .working),
            mode: .closed,
            options: hardOptions,
            at: clock(continuous: 200)
        ))
        hardExpiryRegistry.expire(at: clock(continuous: 260))
        XCTAssertEqual(hardExpiryRegistry.records.first?.state, .unknown)
        XCTAssertTrue(hardExpiryRegistry.activeHolds(at: clock(continuous: 260)).isEmpty)
    }

    func testBootMismatchRemovesHoldsConservatively() throws {
        var registry = WorkloadRegistry()
        XCTAssertTrue(try registry.apply(
            event("start", sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 100)
        ))
        registry.expire(at: clock(continuous: 3, wall: baseWall + 1_000, bootID: "boot-b"))
        XCTAssertEqual(registry.records.first?.state, .unknown)
        XCTAssertTrue(registry.activeHolds(at: clock(continuous: 4, wall: baseWall + 1_001, bootID: "boot-b")).isEmpty)
    }

    func testCommandFinishesSuccessfullyOnlyWithZeroExitStatus() throws {
        var registry = WorkloadRegistry()
        XCTAssertTrue(try registry.apply(
            event("start", source: .command, sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 100)
        ))
        XCTAssertTrue(try registry.apply(
            event("finish", source: .command, sequence: 2, state: .finished, exitCode: 7),
            mode: .closed,
            at: clock(continuous: 101)
        ))
        XCTAssertEqual(registry.records.first?.state, .failed)
        XCTAssertEqual(registry.records.first?.exitCode, 7)

        var noStatusRegistry = WorkloadRegistry()
        XCTAssertTrue(try noStatusRegistry.apply(
            event("start", source: .command, sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 100)
        ))
        XCTAssertTrue(try noStatusRegistry.apply(
            event("finish", source: .command, sequence: 2, state: .finished),
            mode: .closed,
            at: clock(continuous: 101)
        ))
        XCTAssertEqual(noStatusRegistry.records.first?.state, .unknown)
    }

    func testInvalidMetadataPrivacyTimestampAndOptionsAreRejected() throws {
        var registry = WorkloadRegistry()
        let at = clock(continuous: 100)
        let invalidEvents = [
            event("path", session: "/private/file", sequence: 1, state: .working),
            event("unicode", task: "é", sequence: 1, state: .working),
            event("version", sequence: 1, state: .working, adapterVersion: "1/2"),
            event(String(repeating: "a", count: 129), sequence: 1, state: .working),
            event("zero", sequence: 0, state: .working),
            event("future", sequence: 1, state: .working, timestamp: Date(timeIntervalSince1970: baseWall + 6)),
            event("stale", sequence: 1, state: .working, timestamp: Date(timeIntervalSince1970: baseWall - 61))
        ]
        for invalid in invalidEvents {
            XCTAssertThrowsError(try registry.apply(invalid, mode: .closed, at: at))
        }
        XCTAssertThrowsError(try registry.apply(
            event("bad-options", sequence: 1, state: .working),
            mode: .closed,
            options: WorkloadOptions(waitingGrace: 29),
            at: at
        )) { XCTAssertEqual($0 as? WorkloadError, .invalidOptions) }
        XCTAssertThrowsError(try registry.apply(
            event("bad-clock", sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: Double.greatestFiniteMagnitude)
        )) { XCTAssertEqual($0 as? WorkloadError, .invalidDeadline) }
        XCTAssertTrue(registry.records.isEmpty)
    }

    func testIdentityAndRecordBoundsNeverEvictActiveWorkAndStopCanRearm() throws {
        var registry = WorkloadRegistry()
        for index in 0..<128 {
            XCTAssertTrue(try registry.apply(
                event("start-\(index)", session: "s", turn: "t", task: "task-\(index)", sequence: 1, state: .working),
                mode: .closed,
                at: clock(continuous: 100)
            ))
        }
        XCTAssertEqual(registry.records.count, 128)
        XCTAssertEqual(registry.activeHolds(at: clock(continuous: 101)).count, 128)
        XCTAssertThrowsError(try registry.apply(
            event("overflow", session: "s", turn: "t", task: "extra", sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 101)
        )) { XCTAssertEqual($0 as? WorkloadError, .recordCapacityReached) }
        XCTAssertEqual(registry.activeHolds(at: clock(continuous: 102)).count, 128)

        XCTAssertTrue(try registry.apply(
            event("finish-0", session: "s", turn: "t", task: "task-0", sequence: 2, state: .finished),
            mode: .closed,
            at: clock(continuous: 103)
        ))
        XCTAssertTrue(try registry.apply(
            event("start-extra", session: "s", turn: "t", task: "extra", sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 104)
        ))
        XCTAssertEqual(registry.records.count, 128)
        XCTAssertFalse(registry.records.contains { $0.taskID == "task-0" })
        XCTAssertEqual(registry.activeHolds(at: clock(continuous: 105)).count, 128)

        registry.removeAll()
        XCTAssertTrue(registry.records.isEmpty)
        XCTAssertTrue(try registry.apply(
            event("rearmed", session: "s", turn: "t", task: "task-0", sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 106)
        ))
    }

    func testIdentityHistoryIsBoundedAndRequiresRearmAtCapacity() throws {
        var registry = WorkloadRegistry()
        for index in 0..<512 {
            XCTAssertTrue(try registry.apply(
                event("end-\(index)", session: "s-\(index)", turn: "t", sequence: 1, state: .finished),
                mode: .closed,
                at: clock(continuous: 100)
            ))
        }
        XCTAssertThrowsError(try registry.apply(
            event("new", session: "new", turn: "t", sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 101)
        )) { XCTAssertEqual($0 as? WorkloadError, .identityCapacityReached) }
        registry.removeAll()
        XCTAssertTrue(try registry.apply(
            event("new", session: "new", turn: "t", sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 102)
        ))
    }

    func testRecordCodableRoundTripAndMainTurnKeyDoesNotCollideWithTaskKey() throws {
        var registry = WorkloadRegistry()
        XCTAssertTrue(try registry.apply(
            event("main-start", sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 100)
        ))
        XCTAssertTrue(try registry.apply(
            event("child-start", task: "worker", sequence: 1, state: .working),
            mode: .closed,
            at: clock(continuous: 101)
        ))
        let records = registry.records
        XCTAssertNotEqual(records[0].id, records[1].id)
        let data = try JSONEncoder().encode(records[0])
        let decoded = try JSONDecoder().decode(WorkloadRecord.self, from: data)
        XCTAssertEqual(decoded, records[0])
        XCTAssertEqual(decoded.id, records[0].id)
    }
}
