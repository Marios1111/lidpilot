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
Hosted download-byte comparison and Pages publication are tracked separately.

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

## Remaining evidence

G2, G3, full G4, ten-minute performance, RC-to-RC installation, helper replacement
and uninstall remain open. A non-root `proc_pid_rusage` read of the root helper
was denied; no helper memory/CPU numbers are inferred from that failed read.
The initial restricted-runner EBADF test anomaly remains recorded separately;
ten host Runtime runs and CI passed. The tests now require the exact expected
lock-contention error rather than accepting any error (`78ead60`).
