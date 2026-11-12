# Follow Lid built-in brightness — November 12, 2026

## Authority and implementation boundary

The owner requested zero brightness while Follow Lid is closed, restoration on
reopening that preserves original/automatic settings, commits, push, release and
deployment. After public IODisplay control returned unsupported, the owner
approved the narrow private DisplayServices Get/Set exception. Public ColorSync
provides display UUID identity. The helper's privileged command surface is
unchanged; external displays and Low Power Mode are not modified.

This is brightness control, not evidence that the physical panel powers off.
The implementation does not disable automatic brightness or True Tone. If the
brightness has become nonzero during a dim cycle, restoration respects that
newer adjustment. A durable per-app record retains restoration after failure
or restart; a crash can leave the display dimmed until recovery/manual adjustment.

## Automated and signed candidate evidence

- 122 Runtime tests (including 12 brightness backend tests and controller
  integration coverage), 34 Core tests and 16 hostless app tests passed.
- `scripts/verify.sh`, generated-project consistency and `git diff --check`
  passed. Existing native mock smoke rendered the real Debug app, activated
  and cleaned up mock controls, and exited normally. Updated General settings
  rendering was visually inspected.
- Debug and optimized Developer-ID-signed Release builds passed. App and helper
  have publisher team `L69774LN97`, hardened runtime and secure timestamps;
  deep/strict signature verification passed.
- Local installed candidate: 2.0.3/build 21. App executable SHA-256:
  `5adefbff0b107536a636b60845d1b8872b2cfd1021ba3c501ca743990f7714d3`.
  Helper executable SHA-256:
  `f1d54c39a18d1670f8bc1585f574340b61de04b1bd1b19f108566a066e365a4b`.
  These identify the pre-notarization local candidate, not final release assets.

## Native acceptance

On macOS 27.3 (`26C5035r`), with external power, no external display, thermal
state fair, Low Power Mode off and Prevent automatic lock enabled:

1. The owner removed the old helper and quit using the native UI. Independent
   read-back confirmed the service absent and `SleepDisabled=0` before replacement.
2. Signed build 21 was installed with build 20 retained for rollback. The owner
   enabled the replacement helper. CLI read-back confirmed app/helper build 21,
   Off, both assertions off, no lease/ownership/recovery, and the lid open.
3. The owner explicitly opted into a two-minute Follow Lid test. The first
   recorder's launcher exited and its child recorder ended early; its single
   baseline sample is not closed-lid measurement evidence. The owner confirmed
   reopening restored correct brightness. Timer expiry returned Off/override off.
4. A second recorder stayed attached to an active tool session. Its baseline
   native brightness was `0.6548957228660583`. Two consecutive closed-lid samples,
   spanning 1.006 seconds, both returned successful brightness reads of **0**.
   The first reopened sample, 1.006 seconds later, returned exactly the baseline
   value. Subsequent open samples retained that value. The app remained Active
   with the owned helper override on across reopening; the owner again confirmed
   brightness returned correctly. This is a short transition check, not a
   long-duration continuity or physical panel-power measurement.

The probe only read lid/brightness; production app code performed the writes.
Compiler/tool sandboxing initially hid online displays; the unsandboxed native
probe resolved the actual built-in display and getter successfully. The owner
confirmed the lid was open throughout that earlier capability probe.

Logs and captures are local, ignored or temporary:
`/private/tmp/lidpilot-20261112-*.log`,
`/private/tmp/lidpilot-20261112-brightness-samples-2.jsonl`,
`build/native-previews/`, and `release-private/local-validation/2026-11-12/`.

## Remaining boundaries

Other Mac/OS combinations, external/dock/virtual display coexistence, ambient
brightness adaptation during a closed interval, native crash/relaunch restoration,
and long-duration operation have not been newly measured. Existing manual-lock,
agent-adapter and physical panel-off limitations remain. Private API availability
can change; unsupported control fails visibly and releases wakefulness controls.
Final notarization, immutable artifacts, feed/tap publication and deployed-byte
verification are recorded separately in `../VERIFICATION.md` after completion.

## Subsequent installation and cleanup

The actual notarized 2.0.3 public bundle was subsequently installed through
Homebrew and matched the published ZIP's 71 files/symlinks exactly. The compact
native evidence, screenshots, probe source and new installation/cleanup receipts
now reside under `release-private/validation/2026-11-12/`. Bulky temporary build
and test workspaces, native preview output and redundant candidate apps/ZIPs
were removed with the owner's authorization. The earlier temporary paths above
identify where the checks originally ran, not files promised to remain present.
See `../VERIFICATION.md` for installed public hashes and final helper state.
