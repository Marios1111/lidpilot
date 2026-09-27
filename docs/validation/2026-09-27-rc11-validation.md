# RC11 installed closeout — September 27, 2026

Source: `bfbec568866b39a82ba486fbf43212c898808132`, version 1.0.0,
build 11, uninstrumented RC channel. Host: macOS 27.2 beta (26B5091g), arm64.
This is a local validation candidate, not a stable release or public RC upload.

## Build and signing

- 69 Runtime, 21 Core and 10 actual UpdateCoordinator tests pass (100 total).
  Debug and Release builds pass. Additional coordinator tests are test-only;
  their injected dependencies do not establish live OS failure behavior.
- [CI on `7aca04d`](https://github.com/Marios1111/lidpilot/actions/runs/36283332045)
  passed. Subsequent `bfbec56` changed only film source/audio.
- Clean-tree archive, export, app notarization and stapling exited 0.
  Notary submission `e6fb0c1b-2775-4faa-b482-a295816e7c00`: **Accepted**.
- Deep/strict signature validation and Gatekeeper assessment passed with normal
  macOS signing-service access. The initial sandboxed codesign attempt returned
  an internal signing-subsystem error; the normal-access check exited 0.
- App/helper identities remain `com.lidpilot.app` and
  `com.lidpilot.app.helper`, Team `L69774LN97`, Developer ID, hardened runtime,
  arm64. The app has its stapled ticket and branded RC feed.

Artifact staging:
`/private/tmp/lidpilot-rc11-validation-20260927/1.0.0-rc.11-11/`.
The notarization ZIP SHA-256 is
`00cf57b8dcac472bb0cbe79c5356173d30b82d162992a7a6c010972cdfcb64de`.
This is not a final DMG or Sparkle archive hash.

Installed executable SHA-256:

- App: `4861dc575d65cdeb81b919efc00423c7235a74ce2279ed41a6b4efd1c669e3a5`
- Helper: `46c232109a77d22cb0635ef55de0ee55af77e4de969029a5c03806118ecb9eee`

## Installed native checks

The owner explicitly authorized ending the current session and replacing RC10.
Before replacement, native Settings already showed Off. Independent `pmset -g`
showed SleepDisabled=0 and no LidPilot wake assertion remained. Remove Helper
completed through normal Settings UI; RC10 then quit and its app/helper processes
were absent. The prior bundle is preserved at
`/private/tmp/lidpilot-rc10-rollback-before-rc11-20260927.app`.

RC11 launched Off. Preferred behavior Keep Screen On, two-hour duration,
Launch at login On, notifications Off and automatic update checks On survived.
The replacement helper registered Approved. Refresh established XPC reachability
and Off read-back. launchd reported parent bundle version **11**.

A real Check for Updates while Off fetched the signed public RC feed. Sparkle
reported public build 4 as newest and installed build 11 as current. Dismissing
the dialog restored helper registration and removed both `updatePendingBuild`
and `updateRestoreHelper` preferences. During helper restart, Settings briefly
showed **Unverified** with a communication error; one explicit Refresh then
showed reachable **Off**, override off. This transient result is retained rather
than describing re-registration as instant readiness.

Native Diagnostics exposed named power/lid/thermal/assertion values in its
accessibility tree. Copy Status pasted into a new TextEdit document with build
11, State off, Helper Approved, both assertions off, override off, and physical
panel power not measured. The paste was undone and the disposable empty document
closed; the pre-existing snapshot was not edited. Dark Settings rendered without
clipped content. These checks are not a complete VoiceOver/appearance regression
or a measured 100 ms response result.

The authorized brief Keep Mac Running test then reached native **Session active**
with the lid open. Independent macOS output showed SleepDisabled=1, a LidPilot
system assertion (app PID 63034), and no display-sleep assertion. This successful
acquire verifies matching app/helper build compatibility, beyond registration
alone. Turn Off reached native Off, SleepDisabled=0 and no LidPilot assertions.
Keep Screen On and the two-hour preference were restored afterward. No physical
lid or performance result is inferred from this short session.

## Real GUI-crash recovery

The owner separately prepared and approved the GUI-crash test with Keep Mac
Running active, lid open and Settings visible. Native diagnostics showed the
system assertion on and display assertion off. The observer verified the unique
installed GUI PID (63034), SleepDisabled=1 and its assertion before SIGKILL.
Only the GUI was terminated. The first independently observed Off state arrived
at **1.040348 seconds**; every following sample remained Off through 30 seconds.
This is a sampling upper bound, not an exact cleanup-duration measurement.

The app was relaunched; independent read-back remained 0 with no LidPilot
assertions. The owner reopened Settings, where the native recovered UI showed
**Session: Off**, **Helper: Approved**, override off and "LidPilot's controls
are off." There was no false Recovery state or automatic restart. Keep Screen
On / two-hour defaults were restored through native General controls, and
login On / notifications Off remained unchanged. Timed data is retained in
[`2026-09-27-rc11-gui-crash.json`](2026-09-27-rc11-gui-crash.json), including
the hash of the unfiltered local observation record.

## Real Stop & Sleep observation

The owner explicitly approved this intrusive check and opened the mode panel.
RC11 was Off before the action, with independent SleepDisabled=0 and no LidPilot
wake assertions. The native **Stop & Sleep** control was clicked at approximately
04:15:50 +0300. The owner reported: "Mac slept; I woke it."

The macOS power log recorded display off at 04:15:50 and display on at 04:15:53.
It did **not** contain a corresponding system sleep/wake entry in that interval;
therefore this is an operator-observed sleep result with corroborated display
transition, not log-proven system sleep. The app's public IOPMSleepSystem path
was exercised without changing unrelated apps or their assertions. Recovered
native Helper & Recovery showed Session Off, helper Approved and override off;
independent read-back remained SleepDisabled=0. This test started Off, so it does
not independently prove Stop & Sleep cleanup from an active session.

## Remaining

A bounded 30-second Apple Instruments SwiftUI recording successfully attached
to the installed, signed app (PID 71208) while Off. Native Settings navigation
was exercised. It exported 288 frame-update rows (maximum 22.200250 ms),
2,463 SwiftUI update-group rows (maximum 47.626292 ms), and zero potential-hang
rows. Neither duration table contained an interval above 100 ms. These are
render/update measurements, **not exact input-to-visible response latency**;
the 100 ms visible-feedback criterion remains unverified. Timing summaries and
export hashes are in `2026-09-27-rc11-ui-timing.json`.

The original Instruments TOC unexpectedly included inherited shell credentials
and was displayed in tool output. No raw trace or credentials entered Git or
public deliverables. Generated trace permissions were restricted, environment
metadata was removed from the readable TOC, and subsequent exports selected
only timing tables. The owner was informed; credential rotation was not
performed without authorization. Never publish the raw trace or metadata.

Final native/accessibility and response timing, the remaining support/lifecycle
checks and exact stable
distribution remain separate gates. RC10's retained 600-second CPU/memory pass
is unchanged; no new performance result is claimed here. No global sleep policy
was cleared blindly, and no closed-lid test ran during this replacement.
