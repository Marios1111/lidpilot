# Changelog

All notable LidPilot changes will be recorded here. This file describes the
current development snapshot; it is not a release announcement.

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
