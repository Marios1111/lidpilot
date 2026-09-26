# RC10 local lifecycle candidate — September 27, 2026

Source: `d74d76707e4a8c0143e3e8f0991e15e1ed26e83d`; version 1.0.0, build 10,
profiling disabled. This freshly built local candidate contains the
[XPC callback correction](2026-09-27-xpc-callback-recovery.md), event-only
notification diagnostics, and retained RC8 memory correction. It is not a
stable release; no RC10 feed or public binary was published.

- Core/Runtime: **90 tests**, zero failures, exit 0.
- Debug/Release builds: exit 0.
- [Exact-source CI](https://github.com/Marios1111/lidpilot/actions/runs/36275637607): PASS.
- Signed archive/export: exit 0.
- Apple notarization: Accepted, `8df0ab78-db5a-49eb-9d0c-aa9aaa1b6c42`.
- Staple and staple validation: exit 0.
- Deep/strict exported app and installed app verification: pass.
- Exported Gatekeeper assessment: accepted, Notarized Developer ID, exit 0.
  Its initial sandboxed assessment returned a code-signing subsystem error;
  the read-only assessment outside that sandbox passed without changing protections.
- Installed helper strict signature verification: pass.
- Publisher Team: `L69774LN97`.
- App ID: `com.lidpilot.app`; CDHash: `089c560dc137b0038f8994013b2105cd746094d0`.
- Helper ID: `com.lidpilot.app.helper`; CDHash: `580a16c399234913586a17fa413dc59633374544`.
- Helper SHA-256: `06ef41612e996731f976d27a4079bb59192447312cc63e439eb6e861aa5bb15c`.
- Installed bundle-version read-back: 10.

Before replacement, native RC9 Settings reported Session Off / override off.
Remove Helper completed through its normal confirmation flow; Settings then
reported Not installed / Normal macOS behavior. After normal Cmd-Q, a process
check found no LidPilot app/helper, launchd reported the service absent, and
independent SleepDisabled=0 remained. No newer crash report was produced by
that normal quit. RC9 is preserved at
`/private/tmp/LidPilot-RC9-rollback-20260927.app`.

The notarized RC10 export was copied to `/Applications/LidPilot.app` and
launched through native automation. SleepDisabled=0 was independently verified.
The replacement helper registered through normal Settings and became Approved.
Refresh returned Session Off / override off. launchd reported parent bundle
version 10; independent SleepDisabled=0 remained.

The actual Off-state manual updater check displayed the correct no-update
result (public build 4 versus installed build 10). After OK, native automation
briefly timed out, but the same app process (PID 9596) remained running. No newer
crash report appeared; the helper returned with parent bundle version 10 and
both pending-update defaults were absent. The native update status settled to
“You’re up to date!”; Helper & Recovery reported Approved / Session Off /
override off. This installed branch passes the regression for RC9’s reproduced
callback crash. It does not stand in for network-failure/staged-install cases.
Notification diagnosis and final controlled 600-second acceptance remain open.

## Notification delivery and restoration

A controlled one-minute Keep Screen On session ended Off and released its
system/display assertions. Independent SleepDisabled=0 remained. The local
log recorded successful macOS enqueue with public authorization status 2
(authorized). The owner found “Session finished” in Notification Centre,
and repeated that observation on a further manual check. **Delivery PASS**;
no banner was observed and sound was not checked, so neither is claimed.
The foreground presentation callback was not present in the captured event log;
no cause for OS presentation policy is inferred.

Both OS and app notification switches were restored Off in native UI. Original
Keep Mac Running / 30-minute preferences were confirmed; login remained On.
The charger was physically connected and macOS then reported charging on AC.

For final acceptance, native Keep Mac Running became active with a 30-minute
countdown. Independent SleepDisabled=1, a system assertion and no LidPilot
display assertion were verified. App PID 9596 / helper PID 11649, parent helper
bundle version 10, were read before the recorder handoff. Panel and Settings
were closed. The same 600-second inclusive recorder command was supplied to
the operator; no capture result is claimed before its output is complete.

## Installed performance acceptance

Uninstrumented signed build 10, source `d74d76707e4a8c0143e3e8f0991e15e1ed26e83d`,
Keep Mac Running, lid open, charging on AC, native windows closed.
Recorder ran 600.002135 seconds from 2026-09-26 22:35:13 UTC, retaining 121 samples.

- Inclusive CPU: **0.799276989%** of one core — PASS revised ≤1.0% limit.
- App CPU: 0.135664205%; helper own CPU: 0.080696393%; reaped fixed-command children: 0.582916391%.
- Combined physical footprint: **72.262662 MiB mean / 72.392181 MiB sampled maximum** — PASS ≤75 MiB.
- Interrupt wakeups: 1.181662/s; package-idle wakeups: 0.158333/s.
- Energy counter: 205567845 nJ; this is not Activity Monitor Energy Impact.
- Raw capture: `2026-09-27-rc10-acceptance.json`, SHA-256 `74926569b53f85a30970267fbc7e5c1f097c26043af4598285cc5129d341769e`.

No architecture or safety changes were made during the capture. UI-response measurement
and verified post-capture Off cleanup remain pending; performance is not a stable-release approval.

Post-capture cleanup was completed through the native Turn Off control. The panel
reported Off / Normal macOS behavior; independent `pmset -g` reported
SleepDisabled=0 and assertion enumeration contained no LidPilot owner. Other
apps' assertions were preserved. Five-second inclusive CPU maximum was
3.412561%, with no interval above 5%; no sustained runaway was indicated.
UI latency remains unmeasured.

## Diagnostic save branch

While Off, native Diagnostics → Preview Export → Save Report was completed
to `/private/tmp/LidPilot-RC10-diagnostics-validation-20260927.txt`. Independent
file inspection confirmed 4628 bytes, UTF-8 report heading and truthful Off,
Approved helper, external power, open lid, nominal thermal, assertions off,
sleep flag off and physical panel power not measured. SHA-256:
`22c48432a6b646a4aeedd5c3251c04c65f09a1939118d018332785a5e11af377`.
The local event report is retained outside Git. This passes successful save;
the earlier RC6 prolonged active-dialog renewal evidence remains separate.
