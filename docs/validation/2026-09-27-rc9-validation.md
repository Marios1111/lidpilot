# RC9 local signed validation candidate — September 27, 2026

Exact app source: `5a6ee452fc5ed096a809fe9c3834c8f737a25e74`; version 1.0.0,
build 9, profiling disabled. This candidate contains the [notification correction
and updater observation fix](2026-09-27-notification-presentation.md), retaining
RC8's bounded icon bitmap and unchanged helper/safety semantics. It is not a
stable release and no RC9 feed or remote artifacts have been published.

- Full automated suite for the notification correction: 89 tests, exit 0.
- Debug/Release builds: exit 0; isolated actual mock-app smoke: exit 0.
- [Exact-source CI](https://github.com/Marios1111/lidpilot/actions/runs/36273694261): PASS.
- Signed archive/export: exit 0.
- Apple notarization accepted: `2112a61a-4ff8-4db2-b2ec-856c16c916ea`.
- Stapling and staple validation: exit 0.
- Deep/strict bundle signature verification: exit 0.
- Independent helper strict signature verification: exit 0.
- Gatekeeper: accepted, Notarized Developer ID.
- Publisher Team: `L69774LN97`; app ID `com.lidpilot.app`, helper ID `com.lidpilot.app.helper`.
- App CDHash: `9a978565808690506eb8ad161b6b37e436b68a48`.
- Helper CDHash: `b0d419415e9498c5a4936a4dce5ac610fdb0c9a1`.
- Helper SHA-256: `b489143035a8c9821afb9b0f9b7cbb36359fa624e976cf244d4a6fa5517201dd`.
- Bundle version read-back: 9; feed: `https://lidpilot.app/rc/appcast.xml`.

The old RC8 helper was removed through its normal UI after native Session Off,
override off and independent SleepDisabled=0. Settings then reported Helper Not
installed / Normal macOS behavior. The app was quit normally; a process check
found no LidPilot app/helper. The signed RC8 rollback is retained outside
Applications at `/private/tmp/LidPilot-RC8-rollback-20260927.app`.

RC9 was copied from the notarized export to `/Applications/LidPilot.app`; its
installed deep/strict signature check passed. It launched Off. The replacement helper registered through normal Settings UI
and reports Approved; Refresh returned Session Off and override off. launchd
reports the production helper running with parent bundle version 9. Independent
SleepDisabled=0 was confirmed. No stale update/recovery result is inferred merely
from registration.

With the existing temporary-test approval, both notification switches were turned
On and a one-minute Keep Screen On session was started. Native system/display
assertions appeared with bounded deadlines. The panel returned Off with “Your
session has ended.” Independent SleepDisabled=0 and no LidPilot assertions were
confirmed. Both notification switches were restored Off; mode/duration restored
to Keep Mac Running / 30 min; login remained On. The operator reported no banner/sound and no Notification Centre entry.
Delivery is therefore not passed. Existing diagnostics contain no enqueue error,
but that alone does not prove enqueue or delivery. Bounded event-only diagnostics
are being added to distinguish macOS request acceptance/authorization from the
foreground presentation callback; this is not a claimed notification fix.

The final controlled 600-second AC acceptance remains pending a quiet ready
setup; no performance PASS is inferred from signing or compilation. This candidate
retains RC8's memory correction and consolidates its notification/lifecycle fixes
for the fresh installed acceptance rather than repeating an obsolete build.

## Installed updater regression — reproduced failure

The native Off-state Check for Updates action returned Sparkle's correct
no-update result (published RC4 build 4 versus installed build 9). Dismissing
that dialog was followed by an actual app crash at 01:01:30 local time.
The retained system report is `LidPilot-2026-09-27-010132.ips`, incident
`C13AAB07-F51B-4084-93A4-D3BE06E23C6A`, installed build 9. Its faulting queue
is `com.apple.NSXPCConnection.m-user.com.lidpilot.app.helper`, with
`dispatch_assert_queue` / Swift executor isolation checking and an
`NSXPCConnection` error callback on the stack. Root-cause investigation is in
progress; this is not treated as an automation-only error or a passing updater
lifecycle test. Independent SleepDisabled=0 was confirmed afterward. No final
performance acceptance will be inferred from this candidate before remediation.

The app was relaunched through native automation. Independent checks found no
LidPilot wake assertions and SleepDisabled=0. The pending-build and helper-repair
defaults were absent; launchd reported the replacement production helper running
with parent bundle version 9. Thus the crash does not demonstrate failed power
cleanup or persistent update markers. Exact-binary symbolication identifies the
XPC transport error handler; that callback defect remains a release blocker.
