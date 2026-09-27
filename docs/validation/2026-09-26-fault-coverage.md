# G3/G5 recovery and update fault coverage — updated September 27, 2026

This matrix separates deterministic injected tests from behavior observed in a
signed installed app/helper. Safe injection may establish fault-handling logic
when an OS fault is unsafe or impractical to trigger. It does not prove the
installed OS integration, so remaining platform boundaries stay explicit. The
owner accepts the recorded macOS beta host for V1 validation; this document
continues to identify that OS build as beta.

## Evidence matrix

| Area | Deterministic test evidence | Retained installed evidence | Remaining evidence / next action |
| --- | --- | --- | --- |
| Enable, read-back, restore | `HelperEngineTests.failedEnableReadbackRollsBackAndVerifiesCleanup` injects an enable read-back error followed by verified rollback. `failedCleanupReadbackRemainsPendingUntilWatchdogRetry` injects a second read error and checks recovery remains pending until watchdog retry. `failedEnableStillRestoresActualMutation`, `failedRestorationRemainsVisibleAndRetries`, and journal-phase tests cover command failure, retry, flag drift and ownership uncertainty. | Ordinary installed recovery remains verified: RC2 lease expiry and helper crash/restart, RC3 finite expiry, and GUI termination. Most recently, RC11's authorized GUI SIGKILL began with the real override/assertion active; the first Off sample was 1.040348 seconds later and all samples stayed Off through 30 seconds. Relaunch showed native Session Off, Helper Approved and no false Recovery or automatic restart ([RC11 record](2026-09-27-rc11-validation.md)). | Injected read/restore branches are covered. The exact remaining boundary is that these tests exercise `HelperEngine` with a test platform, not a failed production `PMSetDriver` call through the signed helper. Do not induce an unsafe fault on the operator's installation; preserve this boundary as unverified installed behavior. |
| Journal faults and restart | `corruptJournalRequiresExplicitRecovery` uses a throwing mock journal and proves acquisition does not mutate before explicit recovery. `incompleteJournalPhasesNeverClaimAnUnownedOverride`, `enableHasDurableInFlightAndVerifiedPhases`, and `helperRestartRecoversBeforeNewRequests` cover phase logic. Disposable `NativeBoundaryTests` reject malformed JSON, 4097-byte records, loose 0644 record permissions, symlinks and unsafe directory permissions; rejected record bytes are preserved. | Real helper restart/replacement-helper lease behavior and RC11 app-crash recovery are retained, but no installed run exercises a faulty journal through the privileged root path. | Deterministic file and recovery logic is covered. The exact missing boundary is real installed journal ancestry/ownership/no-follow handling and its interaction with the root helper. Do not corrupt the operator's journal; use a disposable account/path only if safe. |
| Command timeout and unreaped-child fence | `PMSetDriverTests.runnerBoundsExecutionAndReapsTimedOutChild` times out and reaps a short `/bin/sleep` child. `inheritedFenceStaysBusyAfterParentDescriptorCloses` checks a live child retains the fence; `HelperEngineTests.oldChildSettlesBeforeRestartReadsOrRestores` and fence-timeout retry tests check ordering and recovery. | No retained signed-helper record demonstrates a real five-second `pmset` timeout or production child-kill/reap. | The timeout/reap path is covered with a bounded test process, not the production `pmset`/ServiceManagement path. The exact uncovered branch is failed kill/reap; the live-child test only proves the fence stays held while a child is alive. A safe isolated runner injection can cover that branch; do not induce it against the production helper or weaken the fence. |
| Delayed, expired, or stale replies | `SessionControllerTests` delays acquire/renew replies across Stop or safety interruption and prevents reactivation. `HelperEngineTests` covers hard-deadline expiry during enable/renew and a Stop tombstone rejecting delayed activation. These use in-memory transports, not XPC. | RC2 app suspension exercised lease expiry; RC3 exercised a finite deadline. RC11's crash/relaunch record confirms cleanup and no automatic restart, but does not exercise a late XPC reply. Signed XPC identity and malformed-request rejection are separately retained. | Controller/helper stale-reply logic is covered deterministically. The exact untested platform boundary is delayed reply delivery through real XPC after Stop, safety interruption or deadline; do not require synthetic input or an unsafe power fault to test it. |
| App update barrier and interrupted-update state | The [10-test actual-coordinator suite](2026-09-27-updater-fault-tests.md) compiles `UpdateCoordinator` and uses the real `SessionController` with scripted updater/helper adapters and temporary UserDefaults. It covers same-build interruption markers and relaunch barrier, post-upgrade cleanup/helper repair, approval-required repair hint, injected unregister and network failures, duplicate callbacks cleaned once, active-session automatic/manual check veto, lid close during preparation, committed-install barrier across relaunch, closed-lid termination veto, and failed helper restoration. These are deterministic coordinator results, not live Sparkle or ServiceManagement failures. | Signed RC1→RC4 upgrades relaunched Off with replacement helpers; RC3's real RC4 check was canceled with **Remind Me Later** before download and left no pending defaults, the old helper registered, and power controls Off. RC11 performed a real signed-feed no-update check and restored its approved helper after dismissing the result; this was not an interrupted install. | Coordinator decisions for injected interruption, network, lid and helper failures are covered. Remaining installed G5 boundaries are a real scheduled Sparkle callback while active, interrupted live install/relaunch, real network loss, lid close during the live update window, ServiceManagement failure, cancellation after staging, and no automatic session restart on an interrupted/failed live update. Do not count the injections as proof of those OS paths. |
| ServiceManagement replacement and uninstall | `HelperTransportTests` deterministically checks accepted identity pairs and fail-closed mismatches. The coordinator suite injects approval-required registration, unregister failure and helper-restoration failure. No test invokes production `SMAppService`. | RC11's installed helper was Approved/reachable, acquired a real lease and restored after its signed no-update check. [RC10 orderly uninstall and same-bundle restoration](2026-09-27-uninstall.md) verifies normal helper/login cleanup and reversible app removal. | Normal install/uninstall paths are retained. The exact missing OS boundary is real approval/failure behavior during ServiceManagement registration/unregistration and mismatched replacement-helper rejection during an actual update; the final stable artifact's update/uninstall lifecycle remains open. |

## Current deterministic test record

The current RC11-source result is retained in
[`2026-09-27-rc11-validation.md`](2026-09-27-rc11-validation.md): 69 Runtime,
21 Core and 10 hostless app-coordinator tests passed (100 total). The app suite
compiles the production `UpdateCoordinator` source and uses injected
ServiceManagement, Sparkle, power and temporary-defaults adapters; it does not
launch the GUI or exercise live OS fault behavior. See
[`2026-09-27-updater-fault-tests.md`](2026-09-27-updater-fault-tests.md) for
the ten cases, reproduced duplicate-cleanup regression and retained logs.

### Historical read-back regression run

At the time of the September 26 audit, the helper test seam exposed
`TestPlatform.failRead`, but no test used it. Two tests were added to distinguish
a transient activation read-back failure whose rollback verifies successfully
from a second read failure that must leave recovery pending until watchdog
retry. The additions changed no Runtime or App behavior.

Focused verification on the inspected worktree (`HEAD 0eadcce` plus the local
test edit):

```text
swift test --disable-sandbox \
  --scratch-path /private/tmp/lidpilot-rc6-fault-coverage/root \
  --cache-path /private/tmp/lidpilot-rc6-fault-coverage/Cache \
  --filter HelperEngineTests
Result: 26 tests passed.
```

The worker performed only the focused deterministic Runtime check. The lead
subsequently ran `scripts/test.sh` on `5e9420e` plus these two test additions:
64 Runtime and 21 Core tests passed (85 total), exit status 0. No installed
app/helper fault injection or new hardware capture was performed for this matrix.

## Retained record pointers

- [G3/G4/G5 procedures and required cases](../HARDWARE_VALIDATION.md)
- [Recovery model and update cleanup boundary](../RECOVERY.md)
- [Current gate status and distinction between tests and installed evidence](../VERIFICATION.md)
- [RC1 signed install and GUI-crash recovery](2026-09-21-native-and-release.md)
- [RC2 lease/helper crash and RC2→RC3 install](2026-09-23-closed-lid-and-lease.md)
- [RC3→RC4 canceled check and signed install](2026-09-24-rc4.md)
- [RC11 installed GUI-crash/recovered-UI record](2026-09-27-rc11-validation.md)
- [10 actual-coordinator update-fault tests](2026-09-27-updater-fault-tests.md)
- [Owner's retained limitation and unresolved gates](2026-09-25-audit-closeout.md)
