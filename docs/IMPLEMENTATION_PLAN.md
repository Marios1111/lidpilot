# LidPilot implementation plan

## Homebrew upgrade follow-up — September 29

The installed upgrade exposed an existing Homebrew/manual normal-quit guard
bug. The narrow 2.0.2 build 17 correction and update-coordinator regression
tests, signed publication, the installed Homebrew upgrade, preference
restoration and cleanup of newly generated builds are complete. The owner
confirmed normal Quit and reopening with Homebrew selected on the final
installed build.
See `VERIFICATION.md` for evidence.

## Agent Tasks usability follow-up — September 29

Implement the owner's menu-bar toggle, clear active task status, optional hiding
while off, and native Codex connection setup. This is a 2.0.1 patch, retaining
V2's experimental adapter and unchanged power/helper contracts. Implementation,
focused review, native checks, signed GitHub/Pages publication, Homebrew tap
update and scoped Xcode debug-artifact cleanup are complete. The existing
2.0.0 installation was preserved for the documented user-run Homebrew upgrade.
See `VERIFICATION.md` for current evidence.

## Completed implementation and release — September 29, V1.1 + V2.0

The authorized scope is developer tools and workload sessions from the updated
blueprint, plus modest Settings/menu-bar polish. V2.1/V2.2 rules, schedules,
App Intents/Shortcuts and remote control are excluded. Stable **2.0.0 build 15**
is published on GitHub, the Homebrew tap and the stable website/feed. The original
V1 GitHub artifacts remain unchanged.

- Implemented: opt-in local CLI, JSON diagnostics, global shortcuts and update
  ownership; bounded manual/task arbitration; command supervision; reversible,
  minimal Codex/Claude hooks; native task UI and Settings.
- Review corrections: fresh restart after manual expiry, independent assertion
  timeouts, same-owner lease replacement with a fresh post-sampling clock, and
  refusal to route an uncorrelated Claude Stop onto a newer turn.
- Final proof: Core/Runtime and hostless app tests, Debug/Release builds, actual
  mock-app CLI/TTY integration, light/dark rendering, and static release checks.
  Consult `VERIFICATION.md` for their final results and exact source revision.
- The owner subsequently authorized signed installation, bounded physical and
  recovery checks, and V2 publication. Build 13 continuity passed; a concurrent
  command admission race was found and fixed. Build 14 verified that fix, deadline
  transitions and GUI-loss cleanup. Stable signing/notarization, publication and
  the real V1-to-V2 Homebrew upgrade passed. The installed app is Off, helper
  and login preference restored, and temporary CLI access disabled. Adapter
  promotion still requires G6; the Claude
  correlation limit stays explicit. See the current verification ledger.

The historical V1 plan follows; its old continuation notes do not describe the
current implementation or supersede the verification ledger.

Initial implementation checkpoint (historical): implementation and safe automated/native smoke checks were complete. The user delegated final design to Astra Max, retaining Mode Cards and the compact timer. User-facing labels are Follow Lid, Keep Screen On, and Keep Mac Running; internal semantics remain smart/display/closed. The September 21 native mock interaction and accessibility-tree pass is complete, including timer choices, settings, export, onboarding, and two verified UI fixes. The follow-up accessibility QA is complete: keyboard navigation, user-assisted VoiceOver speech confirmation, Light/Dark, Increase Contrast, Reduce Transparency, and Reduce Motion. macOS does not list LidPilot as supporting its preferred-reading-size control; that limitation is documented. Original system settings were restored. Hardware, signed XPC, notarized upgrades, and performance measurements remain explicit release gates. No hardware power tests or privileged installation are authorized by this plan. See `VERIFICATION.md` for evidence and the exact resume point.

## Current continuation — September 26

Source checks and CI pass at `3b5a1e6` (85 tests); current committed source is
`8338a8c`. Preserve all retained measurements and physical evidence. The owner
revised V1 CPU acceptance to ≤1.0% inclusive over 600 seconds, with ≤75 MiB
memory and no sustained pathological behavior; safety semantics are unchanged.
The isolated hidden-UI candidate failed a native order-out lifecycle check and
is not merged. Finish the bounded runner check, fix only a demonstrated defect,
then make one final clean installed acceptance run and stop performance work
once it passes. Continue lifecycle/accessibility/release gates afterward.
The film is being reworked as an animated Remotion marketing story with
ElevenLabs young-male narration. Domain/feed migration and initial site polish
are committed; publication and final media checks remain separate.

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

Review public assertion semantics and relevant compatibility sources for a narrow fixed `pmset` backend, launchd helper packaging, and Sparkle integration. Document the supported baseline: no brightness writes or synthetic activity, release display holds on close, native panel handling first, no unvalidated blanket fallback. Prepare opt-in G1/G2 hardware experiments with distinct manual/ambient/inactivity/panel observations. Do not run intrusive experiments automatically.

Proof: minimal app builds; core tests run without root or global mutations; source-backed feasibility notes distinguish API constraints from physical findings.

## 2. State model, session clock, and policy

Create `Core/` values for mode, lifecycle, generation/session identity, timestamped known/unknown observations, effective behavior, reason, confidence, and helper capability. A serial coordinator owns intent and immutable UI snapshots. Define injectable continuous/absolute clocks; duration includes machine sleep, until-time has an explicit dated timestamp, and a time-zone change never extends a deadline.

Implement presets (30m/1h/2h/4h), custom/until-time/indefinite sessions, preserved deadlines on switching, launch Off, and generation cancellation. Implement thermal, 10/20/30% battery floors, unplug, battery-operation preference, LPM, stale-read rules, and latched safety pauses with explicit restart.

Proof: deterministic tests for boundaries, sleep/wake/deadline behavior, all mode transitions, Start→Off, Smart→Display→Off, safety versus delayed activation, timer expiry during reconnect, and unknown readings.

## 3. Protocol, helper, and recovery

Define minimal versioned XPC DTOs and allowed operations (`inspect` (including health), `acquire`, `renew`, `release`, `recover`) with bounded payloads and structured errors. Authenticate expected application/helper identity and signing team using supported peer requirements, never PID alone. Validate session/generation ownership, replay, protocol/build compatibility, and console-user identity.

Implement a fixed-path pmset adapter with only allowlisted read/write operations and a bounded child process. Serialize mutations, prevent late/orphaned enable operations from landing after restoration, and keep watchdog scheduling independent of child completion. The helper samples essential safety independently.

Use an atomic root-owned journal written before mutation with restricted permissions and no client-controlled paths or symlink traversal. Recover before accepting new leases; use boot identity for persisted timing interpretation. Target 15s heartbeats, 60s maximum renewable leases (expiry detection plus bounded restoration, not exact physical timing), and 10s watchdog checks, bounded by the session hard deadline. Retain recovery pending on uncertain/failed restoration, with conservative retry and explicit ambiguous-state recovery.

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

## Owner-approved closeout additions — September 27, 2026

The current owner added Homebrew installation and Copy Status to V1. CLI and
configurable global shortcuts remain deferred. Settings should appear temporarily
in the Dock/Cmd-Tab, returning to menu-bar-only when its window closes.

Homebrew is an installation channel; Sparkle remains the routine in-app updater.
The owner accepted required native cleanup before Homebrew removal/replacement:
Turn Off, disable login, Remove Helper, confirm removal, Quit. Supported cask APIs
cannot enforce that sequence automatically; no private hook or privileged cleanup
bypass is permitted. Validate a manifest-derived stable cask and its real signed
artifact before claiming the installation route is ready.

RC10 inclusive CPU/memory and orderly uninstall/restoration passed. Remaining
work: actual updater persistence/callback fault coverage, final hardware/native
accessibility and original 100 ms visible-response validation, then exact-source
tests/CI and freshly built stable artifacts. The polished RC website was separately
authorized and published through Pages; this does not approve stable release.

### Public launch presentation continuation

- Approved one-time RC Pages publication completed at `13342a8` (run
  `36279153700`); production stable feed remains unpublished.
- Public-facing README rewritten around benefits, actual RC download, support,
  cleanup and developer entrypoints. Stable download/cask links stay gated.
- Homebrew copy block prepared for `brew install --cask Marios1111/tap/lidpilot`;
  native hidden attribute remains until exact published cask installation passes.
- Owner requested Astra Max review of film pacing, pauses, synchronization and
  free/open-source/Homebrew messaging. Revised ElevenLabs narration generated
  two takes; two failed provider concurrency limits without retries. The revised
  45-second film is committed at `2b3153c`, with captioned 1080p landscape and
  portrait exports and a 1.9 MB 720p web export in the dated local deliverables.
  Scene cuts follow measured speech pauses without speeding up the voice.
  Owner listening review and verified Homebrew availability remain publication
  prerequisites. See `media/film/LAUNCH_CANDIDATE.md`.
