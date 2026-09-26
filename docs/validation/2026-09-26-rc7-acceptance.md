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

The controlled run completed 600.001829 seconds, 121 samples, from
2026-09-26 20:17:57 UTC. Raw report SHA-256:
`d5876eeffc67d007275722adeeb7e3b75ef528468e0104b861e61eba53398082`.

| Metric | Result |
| --- | --- |
| Full process tree CPU | 0.903800710% — PASS ≤1.0% |
| App CPU | 0.244045180% |
| Helper own CPU | 0.077764485% |
| Helper reaped children CPU | 0.581991045% |
| Combined physical memory mean | 75.648805 MiB — FAIL ≤75 MiB |
| Combined sampled maximum | 76.032715 MiB |
| App/helper mean footprint | 70.791273 / 4.857531 MiB |
| Interrupt/package-idle wakeups | 1.109997 / 0.135000 per second |
| Reported energy | 424,775,970 nJ; limited public counter, not Energy Impact |

No process restart or invalid counter was reported. App sampled footprint
remained within 70.61–71.16 MiB; no sustained growth is apparent. This does
not prove every possible busy-loop path absent. The reproduced EOF spin is
covered by its focused regression. UI-response timing remains pending.

After capture the native panel showed the active Keep Mac Running session.
Turn Off completed; UI reports Off/normal macOS behavior, independent `pmset`
reports SleepDisabled=0, and no LidPilot assertion is listed. CPU work is closed
under the revised gate; overall performance remains open for memory.

An Off-state `vmmap -summary` attributes 16.2 MiB virtual / 11.5 MiB dirty to
CG Image regions. Source inspection found an explicit 512-point application-icon
raster copy made from the 1024-pixel named artwork, in addition to artwork used
by 28–54-point in-app marks. This is a bounded memory attribution lead, not yet
an installed reduction or a release pass.
