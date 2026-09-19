# LidPilot V1 implementation plan

Status: requirements inspected; repository guidance and interactive design comparison are complete. Native application implementation is pending the user's design choice from `design/index.html`. No hardware power tests or privileged installation are authorized by this plan.

## Outcome and fixed decisions

Implement the V1 scope in the updated planning edition 1.1 PDF and Markdown linked in `AGENTS.md`. Deliver a native arm64 macOS 15+ menu-bar app with three modes, verified Off, bounded sessions, conservative safety, a narrowly authenticated helper, recovery, Sparkle 2, release scaffolding, documentation, and a small static website. The implementation can be complete while public release remains gated on real hardware and publisher credentials; label those distinctions explicitly.

Use Swift 6 with a pure Swift policy package, an Xcode app/helper project, SwiftUI views, AppKit integration where needed, IOKit assertions/observers, ServiceManagement, and a reviewed pinned Sparkle 2 release. The initial candidate is 2.10.0, confirmed against upstream during inspection. No other production dependency is assumed.

The Astra lead owns architecture, transition contracts, security decisions, integration, and final rendered assessment. Luna Max may implement bounded modules with explicit file ownership. One technical owner reviews the complete task diff; independent review is reserved for a specific material trust-boundary risk.

## 0. Review the design before implementation

- Provide four distinct, interactive HTML directions: Quiet Glass, Mode Cards, Native Compact, and Session Focus.
- Include mode, duration, Off/Starting/Active/Paused/Unverified/Recovery examples, dark appearance, and settings previews. All observations are clearly simulated.
- Verify desktop/narrow layouts, keyboard operation, reduced motion, and interactions in a browser. Obtain the user's direction, including any preferred combination.
- The HTML is a decision artifact. Implement the approved design natively afterward.

## 1. Foundation and feasibility record

Create the app/helper project and pure policy package, version/build configuration, project-local build/run entrypoint, and appropriate ignore rules. Record the initial empty repository and use `dev`. Keep release identities/configuration explicit and unconfigured until supplied.

Inspect public assertion semantics and relevant compatibility sources. Document the supported baseline: no brightness writes or synthetic activity, release display holds on close, native panel handling first, no unvalidated blanket fallback. Prepare opt-in G1/G2 hardware experiments with distinct manual/ambient/inactivity/panel observations. Do not run intrusive experiments automatically.

Proof: minimal app builds; core tests run without root or global mutations; source-backed feasibility notes distinguish API constraints from physical findings.

## 2. State model, session clock, and policy

Create `Core/` values for mode, lifecycle, generation/session identity, timestamped known/unknown observations, effective behavior, reason, confidence, and helper capability. A serial coordinator owns intent and immutable UI snapshots. Define injectable continuous/absolute clocks; duration includes machine sleep, until-time has an explicit dated timestamp, and a time-zone change never extends a deadline.

Implement presets (30m/1h/2h/4h), custom/until-time/indefinite sessions, preserved deadlines on switching, launch Off, and generation cancellation. Implement thermal, 10/20/30% battery floors, unplug, battery-operation preference, LPM, stale-read rules, and latched safety pauses with explicit restart.

Proof: deterministic tests for boundaries, sleep/wake/deadline behavior, all mode transitions, Start→Off, Smart→Display→Off, safety versus delayed activation, timer expiry during reconnect, and unknown readings.

## 3. Protocol, helper, and recovery

Define minimal versioned XPC DTOs and allowed operations (`inspect`, `acquire`, `renew`, `release`, `health`) with bounded payloads and structured errors. Authenticate expected application/helper identity and signing team using supported peer requirements, never PID alone. Validate session/generation ownership, replay, protocol/build compatibility, and console-user identity.

Implement a fixed-path pmset adapter with only allowlisted read/write operations and a bounded child process. Serialize mutations, prevent late/orphaned enable operations from landing after restoration, and keep watchdog scheduling independent of child completion. The helper samples essential safety independently.

Use an atomic root-owned journal written before mutation with restricted permissions and no client-controlled paths or symlink traversal. Recover before accepting new leases; use boot identity for persisted timing interpretation. Target 15s heartbeats, 60s maximum renewable leases, and 10s watchdog checks, bounded by the session hard deadline. Retain recovery pending on uncertain/failed restoration, with conservative retry and explicit ambiguous-state recovery.

Proof: mock fault injection for expired/frozen clients, restarted helper, corrupt journal, failed write/read-back, child timeout, replay/wrong peer/oversized request, unexpected flag drift, and interrupted mutation. Inspect authentication and file permissions separately; real signed XPC/launchd fault tests remain hardware gates.

## 4. System integration and mode reconciliation

Implement independently verified IOKit assertions plus event-driven lid, thermal, battery/power, LPM, wake, and display-topology observation. Back up relevant events with low-frequency active reconciliation; no idle sensor polling loop. Smart/Closed must arm while the lid is open; reopen rechecks safety/lease/topology before display behavior returns. Display never needs the privileged helper. Do not change lock security or defeat explicit sleep.

Implement registration/approval, bounded handshake/reconnect, quit cleanup, launch recovery, conflict status, and Stop & Sleep only after verified release. Failed cleanup stays visible. Never treat an active sleep flag as physical panel evidence.

Proof: fake observer/XPC integration tests for rapid lid and topology changes, charger changes during approval, permission revocation, delayed callbacks, app termination, and post-wake reconciliation. Safe app smoke tests must leave the real machine's global power state unchanged.

## 5. Native experience

Implement the selected 340–380-point popover with stable mode controls, duration/end condition, factual status, Start/Turn Off, and secondary Stop & Sleep. Add onboarding, helper explanation/approval, settings, recovery/status view, local bounded diagnostics with export preview, optional session/safety notifications, and launch-at-login (always Off).

Use native semantic colors/materials, system typography, keyboard navigation, VoiceOver labels, Increase Contrast, Reduce Transparency, and Reduce Motion. Avoid hidden per-second UI updates or animation while the popover is closed. Keep appearance adaptive and icon artwork provisional.

Proof: exercise actual `.app` interactions and inspect light/dark, Off/active/error, onboarding/settings, keyboard/accessibility states. Record limitations where automation or hardware access is unavailable.

## 6. Sparkle and safe replacement

Use one standard updater controller; persist the automatic-check preference through Sparkle. Configure HTTPS production feed/public update key as required release inputs, daily checks, no system profiling, no automatic installation, pre-extraction verification, signed feeds/notes, and failure-expiration interval zero.

Inspect callbacks in the pinned SDK and enforce an installation barrier before replacement, not merely before relaunch. Checks must not end a session. Installation requires explicit user intent, open lid, confirmed cleanup, invalidated pending activation, and a quiesced helper. Await ServiceManagement unregister completion, repair stale/incompatible registration conditionally, verify the replacement helper identity/protocol/build, and always launch the new version Off.

Proof: update-gate tests for every lifecycle, all activation entry points, failed cleanup, stale replies, incompatible helpers, and persisted settings. Validate actual Sparkle configuration and signed/tampered archive/feed tooling with disposable fixtures. Signed real upgrades remain a release gate when credentials/previous builds are unavailable.

## 7. Distribution, documentation, and website

Add MIT license, README, CONTRIBUTING, SECURITY, CHANGELOG, issue templates, architecture, safety, recovery/uninstall, threat-boundary, support-matrix, and hardware-checklist documents. Credit technical references and dependency licenses accurately.

Provide local build/test/verify and staged release tooling with dry run/preflight. Verify clean source/version/build, arm64 bundle and nested signatures, hardened runtime, app notarization/stapling, separately finalized signed/notarized/stapled DMG, and final immutable hashes. Generate archive plus feed/notes signatures using matching Sparkle tools and a release manifest. Keep publication explicit: versioned release assets, fetched-byte verification, then exact signed Pages metadata. No remote publishing is part of this execution.

Build a small accessible Pages-ready HTML/CSS site with real screenshots when available, truthful compatibility/release status, install/uninstall, limits, and source links. No trackers or added frontend build system.

Proof: shell/static validation, local package dry runs, malformed/missing-config rejection, bundle structure/signature inspection as credentials allow, and a website browser pass. Unsupplied team, key, feed, or notary identity must block public-release output.

## 8. Final verification and handoff

Build both Debug and Release at the final revision; run relevant automated tests and integration/failure checks. Exercise the actual `.app`, review the full task diff including worker changes, validate Sparkle/packaging, inspect for secrets, and finish with a clean tree. Reuse valid test evidence; broaden tests only for changed assumptions or concrete concerns.

Report feature checklist, architecture, actual owner/reviewer, tests/builds, exact reviewed revision and coherent commits, push status, G1/G2 and remaining hardware/recovery/update evidence, missing publisher credentials, and the next action.

## Commit boundaries

Use natural coherent commits as work is completed: repository guidance; design gallery; state/session model; safety policies; helper protocol/authentication; leases/journal/recovery; native system integration and modes; approved UI/onboarding/settings; diagnostics/lifecycle; Sparkle; release/docs/site; focused integration fixes. Merge adjacent boundaries when that produces a more reviewable change. Inspect each diff; do not accumulate the application into one giant commit.

## Release gates that cannot be replaced by mocks

G1: inactivity dimming while preventing idle-off, tested independently of manual/ambient brightness. G2: physical internal panel shutdown across headless/docked/virtual-display topologies. G3: real GUI/helper crash, recovery, and command-lifecycle behavior. G4: signed peer authentication and journal/launchd security. G5: notarized install, tamper rejection, session-safe signed upgrade, helper replacement, recovery release, and uninstall. No universal hardware, thermal-safety, workload-success, or performance claim follows from implementation alone.
