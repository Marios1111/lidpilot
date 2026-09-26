# G3/G5 recovery and update fault coverage — September 26, 2026

This matrix separates deterministic injected tests from behavior observed in a
signed installed app/helper. Unit and process-runner tests establish their
tested logic; they do not by themselves pass G3 or G5. The owner accepts the
recorded macOS beta host for V1 validation; this document continues to identify
that OS build as beta.

## Evidence matrix

| Area | Deterministic test evidence | Retained installed evidence | Remaining evidence / next action |
| --- | --- | --- | --- |
| Enable, read-back, restore | `HelperEngineTests` covers enable-command failure with rollback, restore-command failure with visible pending recovery and watchdog retry, flag drift, and incomplete journal phases. This audit adds `failedEnableReadbackRollsBackAndVerifiesCleanup` and `failedCleanupReadbackRemainsPendingUntilWatchdogRetry`, which inject thrown read failures after enable and during rollback verification. | RC1 GUI termination restored the override within the first 0.28-second observation; RC2 lease expiry and helper crash/restart restored it by the first changed samples; RC3 finite expiry and GUI termination also ended Off. These were ordinary recovery paths, not injected read/restore failures. | Live failed read-back and failed restore remain explicitly open. In a separately authorized disposable signed install, verify that uncertainty stays visible, retry restores Off, and independent `pmset` read-back confirms cleanup. Do not induce failures against the operator's installed state. |
| Journal faults and restart | `corruptJournalRequiresExplicitRecovery` uses a throwing mock journal and proves acquisition does not mutate before explicit recovery. `incompleteJournalPhasesNeverClaimAnUnownedOverride`, `enableHasDurableInFlightAndVerifiedPhases`, and `helperRestartRecoversBeforeNewRequests` cover phase logic. `NativeBoundaryTests` verifies an empty journal loads as absent, a record round-trips with mode `0600`, symlinks are rejected, and an unsafe-permission directory is rejected. | Real helper restart and replacement-helper lease behavior are retained, but the installed records do not inject corrupt, malformed, unsafe-permission, missing, or symlinked journal state. | G3's real journal-fault cases remain open. Deterministic native-file coverage still lacks malformed/oversized journal bytes and loose journal-file permissions; G4's installed ancestry/ownership/no-follow checks must remain distinct from mock path tests. Any real journal-fault run needs a disposable journal/test account. |
| Command timeout and unreaped-child fence | `PMSetDriverTests.runnerBoundsExecutionAndReapsTimedOutChild` times out a short `/bin/sleep` child and asserts it was reaped. `inheritedFenceStaysBusyAfterParentDescriptorCloses` confirms a live child retains the lock until exit. `HelperEngineTests.oldChildSettlesBeforeRestartReadsOrRestores` models the pre-read fence ordering; fence-timeout recovery/retry is also covered. | No retained signed-helper record demonstrates a real five-second `pmset` timeout, child-kill/reap, or unreaped-child recovery. | The timeout/reap logic has deterministic process coverage, but not the production command or ServiceManagement path. The unreaped error branch is not forced; the live-child lock test covers fencing while a child is still alive, not a failed kill/reap. Keep this as a bounded test-harness/installed-helper case if it can be induced safely; do not weaken or bypass the fence. |
| Delayed, expired, or stale replies | `SessionControllerTests` delays acquire/renew replies across Stop or safety interruption and checks they cannot reactivate the session. `HelperEngineTests` covers hard-deadline expiry during enable/renew and a Stop tombstone rejecting delayed activation. These use `TestTransport`, not XPC. | RC2 app suspension exercised lease expiry; RC3 exercised a finite deadline. Retained signed XPC evidence covers successful calls and identity/malformed-request rejection, but not delayed or stale replies. | G3's real delayed-XPC/expired-deadline interaction remains open. If pursued, use a disposable signed test session and verify final Off plus no later re-enable after the delayed reply arrives. |
| App update barrier and interrupted-update state | `SessionControllerTests.updateBarrierRejectsActiveSessionAndBlocksActivation`, `interruptedUpdateBlocksActivationSynchronously`, and `updateRefusesClosedLidAndRecoveryFailure` prove controller-level barriers and rejection/cleanup. There are no `UpdateCoordinator` or `HelperManager` unit tests, so UserDefaults persistence, Sparkle delegate callbacks, and ServiceManagement errors are not covered here. | RC1→RC2, RC2→RC3, and RC3→RC4 signed installs relaunched Off; replacement helpers were checked, and RC1→RC2 preserved preferences. RC3 verified the manual active-session guard while renewal continued. RC3's real RC4 check canceled with **Remind Me Later** before download and left no pending defaults, the old helper registered, and power controls Off. | G5 still needs scheduled-check deferral evidence; interruption/relaunch with `updatePendingBuild`; network loss; lid close during the update window; cleanup or helper unregister/register failure; cancellation after staging; and no automatic session restart. Test the saved barrier and helper-repair hint across each applicable exit path. |
| ServiceManagement replacement and uninstall | Identity-pair resolution and fail-closed unknown/mismatched identities are deterministic in `HelperTransportTests`; the runtime controller tests do not exercise `SMAppService`. | Signed helper approval, successful RC replacement-helper registration/build matching, and active lease acquisition by a replacement helper are retained. No installed failure-path registration/unregistration record or uninstall run is retained. | On a disposable signed install, cover registration requiring approval/failure, unregister failure blocking installation, replacement-helper mismatch blocking activation, and the documented uninstall only after verified cleanup. Confirm no unrelated sleep settings or assertions change. |

## Focused regression added

The helper test seam already exposed `TestPlatform.failRead`, but no test used
it. Two tests now distinguish a transient activation read-back failure whose
rollback verifies successfully from a second read failure that must leave
recovery pending until watchdog retry. No Runtime or App behavior changed.

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
- [Owner's retained limitation and unresolved gates](2026-09-25-audit-closeout.md)
