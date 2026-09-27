# Changelog

All notable LidPilot changes are recorded here. Stable V1.0.0 was published
on September 27, 2026; earlier RC sections retain their original checkpoint context.

## Unreleased

No V1.1/V2 functionality has started.

## 1.0.0

Released September 27, 2026 — fresh Developer ID signed, notarized and stapled build 12.

- Native Apple Silicon menu-bar app for macOS 15+, with Follow Lid,
  Keep Screen On, Keep Mac Running and Off.
- Preset, custom, until-time and indefinite sessions; battery, charger,
  thermal and Low Power Mode safeguards.
- Authenticated signed helper, independently verified state, bounded commands,
  leases, watchdog and recovery. Development identities are isolated.
- Native settings, onboarding, diagnostics, Copy Status and accessible controls;
  Settings temporarily appears in the Dock and Cmd-Tab.
- Optional notifications, launch at login always Off, and signed Sparkle updates
  while Off. Verified cleanup precedes update and removal.
- Homebrew installation tooling for the signed/notarized release, with documented
  native cleanup before external replacement or uninstall.
- Free, MIT licensed, local-first, with no account or analytics.

V1 validates the built-in-display configuration. Independent idle dimming is
suppressed while the display is kept awake; built-in screen darkness can be
delayed after lid closure. External/dock configurations and genuine different-Team
client testing remain explicitly deferred evidence. No universal panel-shutdown
or task-completion detection claim is made.

## 1.0.0 - release candidate 11

Prepared for final lifecycle validation with Copy Status, temporary Dock and
Cmd-Tab presence while Settings is open, and the duplicate updater-cleanup
correction. Local native preview checks cover status copying and Settings
close/reopen; installed signed-candidate checks now verify build-11 helper acquisition, Off cleanup, status copying, a signed no-update cycle and GUI-crash recovery. Final timing and distribution checks remain. No stable
release or new performance result is claimed by this build-number assignment.

## 1.0.0 - release candidate 10

RC10 fixes a reproduced XPC error-callback actor-isolation crash and adds bounded
notification delivery diagnostics. Signed installed testing confirmed a
Notification Centre entry, a complete no-update cycle, helper coexistence and
cleanup, and orderly uninstall followed by restoration of the same signed app.

The controlled 600-second uninstrumented run passed the owner-revised performance
limits: 0.799277% full-process-tree CPU and 72.262662 MiB mean physical memory
(72.392181 MiB sampled maximum). This local RC is not a stable release; retained
results and remaining gates are in [verification](docs/VERIFICATION.md).

## 1.0.0 - release candidate 9

RC9 contains the foreground session-notification presentation/default-sound
correction and main-actor updater capability observation fix. It retains RC8's
bounded runtime-icon bitmap, existing helper identities and all safety semantics.
This local candidate is for installed notification/lifecycle and final inclusive
CPU/memory acceptance; no stable release or completed gate is claimed.

## 1.0.0 - release candidate 8

RC8 tests a smaller resolved runtime icon after RC7 passed the revised CPU gate
at 0.903801% but narrowly missed the 75 MiB memory budget. The bundled icon
masters and in-app artwork remain full-resolution. No helper or safety semantics
change. The isolated AppKit comparison supports this memory fix; installed
acceptance and remaining release lifecycle checks are still required.

## 1.0.0 - release candidate 7

RC7 is a clean, uninstrumented validation candidate containing development/production
identity isolation, current product artwork and the reproduced child-output EOF
busy-spin fix. It preserves all state reads, watchdog timing and recovery
semantics. Installed acceptance measurement and lifecycle validation are pending;
it is not a stable release. The owner-approved V1 gate is now ≤1.0% inclusive
CPU and ≤75 MiB over the controlled 600-second installed run.

## 1.0.0 - release candidate 6

RC6 tests standard launchd scheduling for the helper while keeping its utility
queues, watchdog cadence, leases, read-backs, and recovery unchanged. A bounded
read-only comparison identified higher per-command CPU under Background
classification. The installed instrumented 600-second run measured 0.543018% inclusive CPU
and 52.56 MiB mean combined physical footprint: memory passed, CPU failed.
The source-matched uninstrumented run on September 26 measured 0.830470% CPU
and 63.32 MiB mean memory on a newer beta OS build. It also failed the former 0.2% CPU gate;
this candidate is not a stable release or an energy pass.

## 1.0.0 - release candidate 5

RC5 supports an explicitly instrumented local diagnostic build. Compile-time
profiling records fixed power-command call sites, read-backs, XPC traffic,
watchdog/heartbeat activity, observer callbacks, and reconciliation. Normal
Release builds exclude it. No read, timer, lease, or safety policy is removed.

This candidate investigates RC4's measured 0.684% inclusive CPU against the
hard 0.2% target. It is not a performance pass or stable V1.0 release. Installed
profiling measured 0.613929% inclusive CPU and 148 fixed reads in 600 seconds.
Remaining release gates are tracked in `docs/VERIFICATION.md`.

## 1.0.0 - release candidate 4

RC4 removes a redundant fixed `pmset -g` read during each closed-lid helper
lease renewal. The 10-second watchdog, 15-second app heartbeat, live reply
read-back, and fixed privileged command boundary remain. A fresh clock check
restores the owned override and rejects renewal if the lease or immutable
session deadline expires between the watchdog preflight and renewal.

This change follows a 600-second installed RC3 Keep Mac Running measurement:
50.57 MiB mean combined physical footprint passed the 75 MiB target, but
0.855% CPU of one core including reaped `pmset` children exceeded the 0.2%
target. The RC4 CPU result was **0.684%**, still above target. Its signed upgrade, physical
display behavior, remaining recovery and authentication cases, and uninstall
remain supervised validation gates. This is not the stable V1.0 release.

## 1.0.0 - release candidate 3

This supervised candidate keeps update checks out of an active session. In
RC1, rejecting an available update opened a synchronous Sparkle error alert;
while the alert remained open, the app's keep-awake assertion renewal was
delayed until its 60-second lease expired. RC3 disables manual update actions
while a session is active and defers update checks until LidPilot is Off. The
installation barrier and signed-update requirements remain in place.

The signed RC1-to-RC2 upgrade, build-2 helper replacement, lease-expiry cleanup,
and helper-crash recovery have been exercised on one Apple Silicon Mac. RC3's
active-session fix and remaining hardware/performance cases still require live
validation. This is not the stable V1.0 release.

## 1.0.0 - release candidate 2

This is a supervised V1.0 release candidate, not a stable release. RC2 fixes a
stale helper approval error after approval completes in System Settings and
handles already-expired macOS keep-awake assertions during cleanup.
Physical display, recovery, helper authentication, performance, and the signed
update lifecycle are still being validated. Use on an open, ventilated desk and
read the verification record before enabling closed-lid support.

### Added

- Native Swift 6 macOS menu-bar shell with mode cards, session duration choices,
  settings, onboarding, local diagnostics, and explicit Off/Starting/Active/
  Paused/Recovery states.
- Pure `LidPilotCore` values for modes, monotonic/absolute deadlines, clock and
  power snapshots, safety policy, typed reasons, and bounded Codable helper
  requests/replies.
- App-scoped system/display assertions for Display and open-lid Smart behavior.
- A narrow authenticated XPC helper path for Smart and Closed behavior, fixed
  `pmset` operations, bounded command execution, renewable lease state, and a
  restrictive recovery journal.
- Session-generation invalidation, hard deadlines, read-back checks, helper
  watchdog recovery, ownership conflict handling, and explicit recovery.
- Sparkle 2.10.0 project/configuration scaffolding and an installation barrier
  that keeps discovery separate from update installation.
- Local build, test, project-validation, and release-metadata validation
  scripts, plus architecture, safety, recovery, and hardware-support docs.

### Fixed

- Give the selected Settings section a stronger outline with Increase Contrast.
- Keep status field names in the accessibility text of grouped Settings rows.
- Size onboarding to its content so introduction and safety text remain visible.
- Clear a stale helper registration error after approval completes in System
  Settings.
- Clear an expired, LidPilot-owned keep-awake assertion ID only after macOS
  read-back confirms the assertion is absent. This addresses the false
  Recovery required state found during the real helper lease-expiry test;
  corrected-build hardware retesting remains a release gate.
- Keep descriptor ownership local until recovery-directory validation succeeds,
  preventing a double close when an unsafe directory is rejected.

### Safety and privacy

- Thermal, battery-floor, Low Power Mode, lid, topology, stale-reading, future-
  sample, and boot-identity checks fail closed where required.
- Battery floors are 10%, 20% (default), and 30%; Smart/Closed pause on battery
  by default and never resume implicitly after a safety pause.
- Diagnostics are local and bounded, with path-like text redaction and no
  analytics, account, cloud, prompt, or workload collection.
- Ordinary tests use mocks and do not install the helper or mutate global power
  policy. Real hardware validation uses a separately authorized baseline and
  ownership/cleanup record.

### Validation status

- Core and Runtime mock/failure tests are useful logic evidence.
- Runtime contention tests now require the expected fenced-command failure, and
  a bounded, inspect-only developer probe is available for XPC client-identity
  checks. Its timeout does not prove authentication rejection.
- Release metadata validation now distinguishes placeholder tokens from
  ordinary release prose.
- RC1's Developer ID-signed, notarized, and stapled app and DMG passed release
  checks. XPC access succeeded for the approved identity and was rejected for
  wrong-ID and ad-hoc clients. GUI crash cleanup completed in 0.28 seconds; a
  10-minute Off sample measured 0.102% CPU and 47.62 MiB mean combined memory.
- Physical display behavior, hardware recovery, the remaining peer-identity
  matrix, active-session performance, a real signed upgrade, and uninstall
  remain open release gates; RC1 results do not clear them.
- The repository is now `Marios1111/lidpilot`; stable artifacts and the update
  feed remain gated on the recorded release-validation results.
