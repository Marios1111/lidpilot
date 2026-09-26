# RC8 installed memory-fix acceptance — September 26

Source: `6d38bd0f9adaf87c2fd82250d1a7de7f8ea0a936`, marketing version 1.0.0,
build 8. This is a local validation candidate, not stable V1. Profiling is off.
The only app behavior change from RC7 is the [bounded runtime-icon bitmap fix](2026-09-26-icon-memory.md);
helper/safety behavior remains unchanged. Native journal tests add coverage only.

- Full automated suite: 89 tests, 68 Runtime + 21 Core, exit 0.
- Debug/Release builds and actual isolated mock-app smoke: exit 0.
- [Exact-source CI](https://github.com/Marios1111/lidpilot/actions/runs/36270408194): passed.
- Signed archive and export: exit 0, arm64, hardened runtime, publisher Team ID `L69774LN97`.
- Notarization accepted: `78eb07f1-c852-425a-b667-da04cacb930a`.
- Stapling and staple validation: exit 0.
- Installed deep/strict signing and Gatekeeper: exit 0, Notarized Developer ID.
- App CDHash: `a18812980b9c328fbb8b9ed276b5a3a77b347e41`.
- Helper CDHash: `81ccf88cf65e36e288fbee7ea9097b58c0148816`.
- Helper SHA-256: `b57ca9625638bec2724ac5156ae6ecb6ab125b0ef49600183222476c4d07502a`.
- RC7 helper removed through normal UI after verified Off; independent SleepDisabled=0.
- RC7 rollback retained outside Applications; only known generated rollback bundles moved.
- RC8 starts Off; replacement helper Approved and reachable. Refresh reports override off.

The next controlled installed 600-second capture is pending. Do not infer a
memory pass from the disposable harness or relabel RC7's failure. Retain the
same full-process-tree CPU accounting, memory, wakeups and cleanup evidence.
No RC8 feed or stable artifact has been published.

## Preflight pause and diagnostic sample

The controlled session acquired successfully with a system assertion and no
LidPilot display assertion. Before starting the recorder, power observation
showed Battery Power at 72% and a separate FaceTime A/V display assertion.
The test was stopped rather than silently substituting this setup for quiet AC.
Native Off, independent SleepDisabled=0 and absent LidPilot assertions were
confirmed. The owner cannot connect the charger at this checkpoint.

A separate five-second **Off, app-only diagnostic** measured 62.165070 MiB mean /
62.172882 MiB sampled maximum for PID 98156. It excludes the helper, is short,
and uses a different session state: it is not the acceptance test or a memory
PASS. Final full-process-tree 600-second capture remains pending AC availability.

## Off-state updater and denied-notification checks — September 27

The installed signed build 8 performed a real manual check against the hosted
RC feed. Sparkle reported that build 4 was the newest available and build 8 was
already newer; no installation occurred. After dismissing that result, Settings
→ Helper & Recovery remained Approved and Refresh reported Session Off and
System sleep override off. Independent `pmset -g` reported SleepDisabled=0;
`pmset -g assertions` contained no LidPilot assertion. Both `updatePendingBuild`
and `updateRestoreHelper` were absent from the production defaults domain
(`defaults read` exit 1, key not found). This passes the real no-update-cycle
helper restoration/marker cleanup branch, not network/interruption failures.

The General notification switch started Off. Requesting notifications left it
Off without disturbing the Off state. System Settings → Notifications → LidPilot
confirmed Allow Notifications Off. Production defaults still contained
notifications=0. This verifies graceful handling of this existing denied OS
permission; notification delivery is not yet proven. Launch at login was On
and was left unchanged. Separate FaceTime assertions were left untouched.

## One-minute expiry and notification attempt

With the owner's approval, macOS Allow Notifications and the app's notification
preference were temporarily enabled. A one-minute custom Keep Screen On session
created both native LidPilot assertions with bounded timeouts. The visible mode
panel counted down and returned Off with “Your session has ended.” Independent
read-back then showed SleepDisabled=0 and no LidPilot assertion. No closed-lid
operation was used; unrelated Safari/FaceTime assertions remained untouched.

The owner did not see or hear a session-finished notification. Automation could
not attach to Notification Centre to inspect delivery. Therefore the notification
presentation/delivery gate is **not passed**. Source inspection found no foreground
notification delegate and no assigned notification sound; these are being corrected
and will require a fresh installed notification test. This does not establish a
background-delivery failure or explain every possible OS suppression condition.
Both notification settings were restored Off; preferred mode/duration restored
to Keep Mac Running / 30 min. Launch at login remained On.

A separately signed development app was briefly launched Off for coexistence
preflight, producing a second menu-bar icon. It was identified by its exact debug
executable path and closed before the notification test. No development helper was
registered and no development session started. Only the installed production app
and helper remained. Full signed-helper coexistence is still pending.
