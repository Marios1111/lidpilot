# Changelog

All notable LidPilot changes will be recorded here. This file describes the
current development snapshot; it is not a release announcement.

## Unreleased - development snapshot

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
- Native inactivity dimming without display-off, physical internal-panel power,
  real signed peer authentication, hardware crash recovery, notarized
  packaging, signed update replacement, and uninstall remain release gates.
- The repository is now `Marios1111/lidpilot`; stable artifacts and the update
  feed remain gated on the recorded release-validation results.
