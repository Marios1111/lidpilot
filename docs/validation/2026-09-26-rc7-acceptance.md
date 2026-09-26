# RC7 clean installed acceptance — September 26, 2026

Source: `f4deb6e7c1e888f781e5d42cca7007a8de97c192`, marketing version
1.0.0, build 7. This is a local release candidate, not stable V1.
Normal Release compilation; `LIDPILOT_PROFILE_BUILD=0`. No hidden-presentation
experiment is included. The EOF runner fix preserves safety semantics.

## Preparation evidence

- Full automated tests: 86 passed (65 Runtime, 21 Core), exit 0 on runner-fix
  revision `4877adb`; candidate only changes version/changelog/evidence.
- Debug and Release builds: exit 0.
- [CI on the exact candidate source](https://github.com/Marios1111/lidpilot/actions/runs/36267877324): passed.
- Clean managed worktree used for archive, preserving concurrent film edits.
- Signed archive and export: exit 0.
- Developer ID app/helper Team ID: `L69774LN97`; production identifiers unchanged.
- Apple notarization accepted: `d61744b6-3453-4c19-adcf-f6b56fee9cda`.
- Staple and staple validation: exit 0.
- Installed deep/strict signature verification and Gatekeeper assessment: exit 0,
  `Notarized Developer ID`.
- App CDHash: `41b3f4ecf0834ad38a36d609e6f0aa29f34764b0`.
- Helper CDHash: `b7cfa25fe362b129c01a88a6626f4d0404235b74`.
- Helper SHA-256: `1b1c7bf2b99e3d06cc24c12e12c7201c72cddb98e28b34cc938fa5633743dc39`.
- Feed: `https://lidpilot.app/rc/appcast.xml`; no candidate feed published.
- Old helper removed through normal UI after verified Off. Independent flag
  read stayed 0. RC6 rollback retained outside the source repository.
- RC7 starts Off. Replacement helper registered normally, Approved; Refresh
  reports Off, override off, normal macOS behavior. Before measurement, no power mutation was made. A controlled 30-minute Keep Mac
  Running session was then started with the lid open and AC attached. UI reports
  Session active and display follows macOS policy; independent reads confirm
  SleepDisabled=1, LidPilot system assertion present, display assertion absent.

## Installed measurement

Recorder SHA-256: `f6965c146bea609a59f487532f891f8f18effc1a9196ad5d3c5d792ba2beb95e`.
App PID 62801, helper PID 63485 at preflight; output requested at
`/private/tmp/lidpilot-keep-mac-running-rc7-acceptance.json`.

Pending the controlled 600-second run. Acceptance requires inclusive app/helper/
child CPU ≤1.0% of one core, memory ≤75 MiB and no pathological busy loop.
Wakeups and UI response must be retained. Historical 0.2% failures are not
retrospectively relabelled as passes. Verify Off and assertion cleanup afterward.
