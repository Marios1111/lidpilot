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
