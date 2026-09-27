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

## Remaining

Installed active-session/helper compatibility, final native/accessibility and
response timing, the remaining support/lifecycle checks and exact stable
distribution remain separate gates. RC10's retained 600-second CPU/memory pass
is unchanged; no new performance result is claimed here. No global sleep policy
was cleared blindly, and no closed-lid test ran during this replacement.
