# Native and release validation — 2026-09-21

This is an incremental evidence record, not final V1 approval. Lead: Astra High.
Bounded tooling/test work: Luna Max. Host: Apple M4 MacBook Air, 24 GB,
macOS 27.2 (26B5086k), built-in display only. Other OS/topologies are untested.

## G1: Keep Screen On, built-in display

Initial installed validation app: 1.0.0 (1), app/runtime source `8cb7fc9`,
timestamped signed wrapper `0e391f4`. No helper was registered for this run.

- 02:25:16 local: started a one-hour Keep Screen On session through the native UI.
- Independent `pmset -g assertions` showed both LidPilot system-idle and
  display-idle assertions, with renewed bounded timeouts. `SleepDisabled=0`.
- The operator confirmed brightness keys worked, shading/unshading the ambient
  sensor changed brightness, and the display stayed lit without idle dimming
  for at least two minutes. The configured display-off timeout was one minute.
- 02:28:21: after clicking Turn Off, both LidPilot assertions were absent and
  `SleepDisabled` remained `0`; unrelated assertions remained present.
- The operator then confirmed normal dimming and display-off during a separate
  untouched two-minute Off interval.

**PASS on this setup for supported Keep Screen On behavior.** Native independent
dim-without-off is not implemented. Apple's SDK `IOPMLib.h` documents that
`kIOPMAssertPreventUserIdleDisplaySleep` prevents automatic dimming and idle
display-off. No brightness writes or synthetic input were used. Follow Lid's
open-lid path and battery/external-display variants still require their own record.

## RC1 signing and packaging

- Source commit: `67a176b8b9b17be88d29d9225df2df61a4483b98`.
- Version 1.0.0, build 1; release label `1.0.0-rc.1`.
- Developer ID team `L69774LN97`; exact app/helper identifiers, hardened runtime,
  secure timestamps and strict signature verification passed.
- App notarization accepted: `88c2b1fa-ef1f-4bf2-b902-6461fe0f2191`.
- DMG notarization accepted: `daea522c-e23f-4477-b49b-36343c9a3bee`.
- App and DMG stapling and staple validation passed. Gatekeeper assessed the
  exported app as accepted, source `Notarized Developer ID`.
- Actual Sparkle archive, release-note and feed signatures validated. The
  archive matched the public key embedded in the app; flipping one byte in a
  disposable copy caused independent Ed25519 verification to fail.
- The real pipeline exposed a placeholder-detector false positive on the word
  “replacement.” Fix `7e97ef4` adds prose/token regression checks. Artifact bytes
  were unchanged; the corrected validator then produced the manifest.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| RC1 DMG | 2,225,237 | `ef0f1ce10bcb35251be77a0c22bfc152f63267ddca17941b4ad21087cd44f8c2` |
| RC1 update ZIP | 1,897,292 | `1e0322d1051cd348334507075b4e3136e05b16cfb6770e8bac7eb0f18d4c9452` |

[RC1 is a public prerelease](https://github.com/Marios1111/lidpilot/releases/tag/v1.0.0-rc.1).
Public RC testing was explicitly approved; it does not approve stable V1.
Its manifest records hardware validation as pending. CI for this source passed:
[run 35544706952](https://github.com/Marios1111/lidpilot/actions/runs/35544706952).
All five release assets were fetched anonymously; their bytes match the local
manifest. The RC Pages workflow passed in run `35545741944` at `b0eaa7d`.
The published feed and notes are byte-identical to their committed signed files;
the hosted feed's Ed25519 signature verifies over its 1,472-byte signed prefix.
The live site was inspected in the browser and its brightness disclosure opened.

## G4: ServiceManagement and real client identity

The notarized RC1 was installed in Applications and launched Off. Registration
reported Approval needed. The operator approved its Background App Activity
with Touch ID; Refresh then showed Approved and a verified off override.
`launchctl print` confirmed the system service, expected parent/helper IDs,
build 1 and team `L69774LN97`. The state directory was root-owned, mode 0700.
The non-root test process could not inspect its contents; permissions were not weakened.

At 02:36:13–14 local, with the app Off and `SleepDisabled=0`:

- A publisher-signed inspect-only probe with the expected identifier received a
  successful helper reply.
- The same probe signed by the same publisher with an incorrect identifier was
  rejected. An ad-hoc probe without a trusted publisher identity was also rejected.
- Both rejected probe processes ended with SIGTRAP. In each case the helper's
  macOS XPC log explicitly recorded “Received message forbidden due to code
  signing requirement”; this was not inferred from a timeout.
- No acquire/renew/release/recover requests were sent by these probes.

These checks establish real positive/wrong-ID/ad-hoc enforcement on this setup.
A separately signed different-team client, wrong-console-user case, helper
replacement and the remaining G4 matrix are not yet verified. The observed
approval flow also left a stale registration error visible after approval; the
next candidate clears that error when refreshed status becomes enabled.

### Signed malformed-wire checks

With the installed RC1 app Off, no LidPilot assertions, and an independent
`SleepDisabled=0` baseline, the publisher-signed developer probe from `9b9ae88`
sent four fixed inspect-only/malformed payloads. Wrong protocol, zero generation,
malformed JSON and valid inspect JSON padded beyond 16 KiB all returned
`success=false`, `failureCode=invalidRequest`. Transport failure or timeout would
have failed this check. All four assertions passed; afterward the override was
still off and no LidPilot assertion appeared. The test acquired no lease and
sent no valid mutation request.

The retained log `lidpilot-invalid-wire-rc1.log` has SHA-256
`a2e476db5ee703b0bc992edc01943335ccb81c3f09b143836fcff56a4410574d`.
This adds real protocol-boundary evidence; it does not substitute for the
remaining different-team/console-user or replacement tests.

## G2: Follow Lid and workload continuity

The native UI reported active ownership and independently sampled
`SleepDisabled=1` before closure. A harmless Python workload appended a UTC and
monotonic timestamp each second, sampling lid/override state every five seconds.
The sustained closed interval was observed from 23:41:52.795 through
23:43:07.021 UTC (75 samples). `SleepDisabled` stayed `1`. A separate read while
closed showed LidPilot's system assertion present and display assertion absent.
After reopening, the display assertion returned.

The operator left an approximately 4 mm viewing gap while the lid sensor
reported closed. They observed the screen staying lit initially, then going
black after about one minute, and normal reopening. This is physical visual
evidence on this setup, not an electrical panel-power measurement or proof of
immediate shutdown. The one-minute macOS display-idle setting was unchanged.
No forced display-sleep command, overlay or brightness manipulation was used.

The complete 359-sample run's largest wall-time gap was 1.0571 seconds, including
the sustained closed interval. It also captured the later GUI-crash cleanup.
Raw data and the exact observer script are retained locally under
`release-private/validation/2026-09-21/`. The trace SHA-256 is
`b8fc40763ad4ac490e40f9790311e1e4fceed112edba0613583eab55e8152e77`.
Keep Mac Running and other available power/support cases still need separate tests.

## G3: real GUI crash

With Follow Lid active and the lid independently checked open, the app was
terminated using SIGKILL. The helper remained running. Read-only `pmset -g`
sampling first observed `SleepDisabled=0` within 0.28 seconds (two samples).
This is an observed upper bound, not a guaranteed worst-case cleanup time.
After relaunch, native Settings showed Session Off, override off, and
“LidPilot's controls are off.” No global reset command was issued by the test.

The local retained record `lidpilot-gui-crash-rc1.json` has SHA-256
`eed1f757e2307e9db17122f327921f9950c8c9b008fd3abfd513bfdb106586cb`.
Only this GUI-crash path has passed; helper loss, lease expiry and fault cases
are not inferred from it.

## Performance: Off, RC1

The operator ran the bounded recorder with administrator access to both RC1
processes (app PID 44995, helper PID 47084). The run started at
23:51:27 UTC on September 20 and lasted 600.008 seconds, with 121 samples at
five-second intervals. Lid open, AC connected, panel/settings closed, session
Off; the final independent read-back remained `SleepDisabled=0`. Battery was
39% and charging at completion. No local build or power mutation ran during it.

| Metric | Result | Target/status |
| --- | ---: | --- |
| Mean CPU, app/helper plus reaped children | 0.1018% of one core | PASS, ≤0.2% |
| Mean combined physical footprint | 47.624 MiB | PASS, ≤75 MiB |
| Maximum sampled combined physical footprint | 47.877 MiB | PASS, ≤75 MiB sampled |
| Interrupt wakeups | 0.3867/s | Recorded; no numeric product threshold |
| Package-idle wakeups | 0.0100/s | Recorded; no numeric product threshold |
| Reported process energy counter delta | 144,171,363 nJ | Accounting value, not Activity Monitor Energy Impact |

The public `proc_pid_rusage` recorder checks process identity throughout and
includes reaped-child CPU time. Wakeup/energy counters cover the named processes;
they are not whole-machine measurements. Sampled memory does not establish
an absolute transient peak. UI feedback latency and the two active-mode runs
remain unmeasured. Raw `lidpilot-off-rc1.json` is retained in the same local
validation directory, SHA-256
`ba64819658c259ec5d337d644879e2ecfad0a913f645812d4234fdc45a7bdac0`.

## Remaining evidence

Remaining G2/G3 cases, full G4, active-mode performance, RC-to-RC installation, helper replacement
and uninstall remain open. A non-root `proc_pid_rusage` read of the root helper
was denied; no helper memory/CPU numbers are inferred from that failed read.
A fresh unrestricted Runtime run at `7e42319` reproduced the earlier EBADF
failure despite passing CI (`35546452910`). Investigation confirmed an actual
ownership bug in `RecoveryJournal.init`: the unsafe-directory rejection branch
closed its stored descriptor, then Swift ran `deinit` and closed it again.
Concurrent descriptor reuse explains why another fence operation could fail.
A standalone reproducer deterministically showed the second close invalidating
a replacement descriptor; this is no longer classified as a runner anomaly.

Fix `9a02faa` validates a local descriptor before transferring ownership to the
journal. Permission checks remain intact. The existing rejection test now
requires the precise error. After the fix, all nine focused boundary/fence tests
passed and ten complete Runtime runs each passed all 51 tests. All 21 Core tests
also passed; fixed Debug compiled. The probe and logs are retained locally.
The earlier failure log remains preserved as `lidpilot-rc2-tests.log`.

RC2 build 2 was initially archived/exported and its signatures verified at
`7e42319`; that unpublished bundle was preserved separately after the fix.
Notarization stopped because `notarytool` could not access `lidpilot-notary`
while native automation reported a locked Mac. The profile worked for RC1;
unlock/retry is required before concluding that credentials are missing.
No RC2 artifact from that attempt was installed or published. A fresh candidate
must include the journal fix before the actual upgrade test.

The fixed RC2 app/helper were freshly archived and exported from `9b9ae88`
as version 1.0.0 build 2. Both passed strict code-signature verification, with
expected publisher team, helper identifier, hardened runtime and secure
signing timestamps. The new candidate is at
`/private/tmp/lidpilot-release-501/1.0.0-rc.2-2/export/LidPilot.app`.
It has not yet been notarized, installed or published. The old pre-fix attempt
is preserved separately under the `-before-journal-fix` staging directory.
Static project/package/release-fixture checks also passed after the fix.

CI [35547329625](https://github.com/Marios1111/lidpilot/actions/runs/35547329625)
passed on exact source `9b9ae8849a8fbe888bf9e6d53f37afab8e5675b6`, including
full package tests, static/release checks, Debug and optimized Release. The
local fixed Debug, signed Release archive/export and strict bundle/helper
signature checks passed separately. No stable `main`, `v1.0.0` tag or release
exists; only `dev` and the approved RC1 tag/release are present remotely.

At this checkpoint, native automation requires a manual unlock. The next
operator-assisted step is Keep Mac Running activation while open, followed by
independent ownership verification and the physical close/reopen test. Do not
start an unobserved closed-lid session. Lease expiry, helper crash/restart,
active-mode measurements and RC2 notarization/upgrade/uninstall are still open.
The current RC1 was independently observed Off with no LidPilot assertions and
`SleepDisabled=0` after the malformed-wire checks.
