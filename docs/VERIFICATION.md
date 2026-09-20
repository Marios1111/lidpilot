# V1 implementation checkpoint

Initial checkpoint: 2026-09-19; native follow-up: 2026-09-21. Source and local development builds are implemented; public
release is blocked by the gates below. No remote publication or push occurred.

Technical owner: the selected GPT-6 Astra Max lead. GPT-5.6 Luna Max handled
bounded Core, diagnostics, project/release, and documentation work. GPT-5.6 Sol
High performed a focused read-only helper security review. Its command-fencing,
journal-phase, admission, and retry findings were fixed by the lead and covered
by regression tests; it was not a second final reviewer. CodeGraph was used for
focused context, with current source and builds as the final evidence.

## Feature checklist

| Feature | Implementation | Remaining evidence |
| --- | --- | --- |
| Native arm64 macOS 15+ app | Swift 6 / SwiftUI / AppKit menu-bar app, original icon, adaptive Soft Glass mode cards | Stable supported OS and interactive accessibility pass |
| Follow Lid / Keep Screen On / Keep Mac Running / Off | Separate requested/effective/observed state, read-back, generation invalidation | G1/G2 physical behavior |
| Sessions | 30m/1h/2h/4h/custom/until-time/indefinite; immutable hard deadlines; switch preserves deadline | Native preset/custom/until-time/indefinite interaction passed; physical timing remains gated |
| Safety | Thermal protection, 10/20/30% battery cutoff, battery/LPM policies, charger/lid/display/wake observation, explicit restart after pause | Live sensor and workload continuity checks |
| Closed-lid helper | Reciprocal signed XPC, console user restriction, fixed pmset operations, bounded child execution, leases/watchdog, journal and conflict handling | Signed authentication, launchd/crash/recovery tests G3/G4 |
| App lifecycle | Starts Off, login preference, helper approval, onboarding, notifications, verified quit and Stop & Sleep | Real approval/login/notification/sleep paths |
| Diagnostics/recovery | Local redacted bounded logs, export preview, cleanup/repair/removal UI, explicit ambiguous-state recovery | Native export passed; privileged recovery remains gated |
| Sparkle 2.10.0 | Manual/daily checks, signed feed/notes/archive configuration, active-session barrier, helper replacement and interrupted-update handling | Real signed upgrade G5 |
| Distribution/community | MIT and dependency notices, README, CONTRIBUTING, SECURITY, CHANGELOG, issue templates, CI, staged signed/notarized DMG tooling | Publisher identity, private reporting route and release inputs |
| Website | Static accessible Pages-ready site, no trackers or build dependency | Publication intentionally not performed |

No CLI, AI-agent detection, process automation, Shortcuts, widgets, remote
control, cloud account, or Homebrew feature was added.

## Checks performed

Environment: Apple Silicon; macOS 27.2 (26B5086k); Xcode 27.0 (27A5252f).
The project targets macOS 15.0, but this newer development environment does not
establish support on macOS 15 or constitute a stable-OS release matrix.

- Debug and optimized Release builds pass through `scripts/build.sh`.
- `scripts/test.sh`: 51 Runtime tests in seven suites and 21 Core tests pass.
  Coverage includes delayed acquire/renew versus Stop, thermal interruption,
  immutable deadlines, unknown reads, recovery retries, phased journal faults,
  inherited child locks, bounded processes, protocol/admission rejection,
  update barriers, and diagnostic rotation/redaction/retention.
- `scripts/smoke-ui.sh` launches the actual Debug `.app` with in-memory power
  controls, separate preferences and no real observers/helper/notification
  mutations. Mock activation, cleanup, five rendered artifacts, and normal
  app exit pass. This caught and fixed a nested AppKit quit-loop problem.
- The lead inspected rendered light/dark panel, active state, onboarding and
  original icon. ImageRenderer does not render native menus or grouped Forms
  completely; its placeholders are not screenshots of working native controls.
- Website browser checks covered desktop/narrow widths, an FAQ interaction,
  overflow, and console errors. No overflow or console errors were found.
- `scripts/verify.sh` passes project/plist/script checks, malformed metadata and
  publication-origin rejection fixtures, and CryptoKit tamper/wrong-key tests.
- The pinned Sparkle tools generated and verified a disposable archive,
  release notes, and signed feed. Tampered archive/feed bytes were rejected.
  The tightened validator also passed the matching GitHub Pages fixture.
- Both bundles pass `codesign --verify --deep --strict`; app/helper executables
  are arm64, the target is macOS 15, and embedded helper/daemon/resources are
  present. These are ad-hoc signatures with no publisher TeamIdentifier.
  Release carries the hardened-runtime flag; Developer ID/notarization is not
  established by these checks.
- A disposable unsigned DMG was created and its checksum verified: 2,461,071
  bytes (about 2.35 MiB). It was not mounted, installed, or published. Final
  signed/stapled size remains a release measurement.
- Project regeneration is byte-stable. The release dry run makes no external
  writes; real release preflight refuses missing credentials, hardware approval,
  configured publication URLs, and the not-yet-finalized versioned changelog.
- Source secret-pattern inspection found no credential/private-key candidates.
  Disposable signing fixtures and build products are outside tracked source.

SwiftPM emitted sandbox warnings about unavailable user-level configuration
caches; tests completed successfully using the disposable scratch/cache paths.
The newer host also warns that `hdiutil create` is deprecated; creation and
verification passed, and the tooling retains the macOS 15-compatible command.

## Artifacts and commands

The September 21 local bundles are under
`/private/tmp/lidpilot-501/DerivedData/Build/Products/{Debug,Release}/LidPilot.app`.
The earlier temporary builds were cleared; temporary artifacts can disappear.
They are development artifacts, not redistributable signed releases. Ignored
`build/` contains build/test logs and native preview artifacts. Temporary
Sparkle fixture locations are `/private/tmp/lidpilot-sparkle-appcast-valid.D7qR9F`
and `/private/tmp/lidpilot-sparkle-githubio-signed.Sj8zFn`; no private key belongs
in Git. The unsigned packaging fixture is under
`/private/tmp/lidpilot-package-check-wm8xbxfo`.

```sh
./scripts/build.sh Debug
./scripts/build.sh Release
./scripts/test.sh
./scripts/verify.sh
./scripts/smoke-ui.sh
./scripts/release.sh dry-run
```

## Resume point and release gates

1. Complete a spoken VoiceOver navigation pass, full keyboard navigation under
   the release candidate's keyboard-access configuration, and live light/high-
   contrast/reduced-transparency variations. The September 21 interaction and
   accessibility-tree checks below passed; they do not establish these remaining
   assistive-technology and appearance cases.
2. Keep the user's running closed-lid controller and its observed `SleepDisabled=1`
   intact. No helper registration, global write, real sleep request, closed-lid
   test, or controller termination was performed in this implementation task.
3. Obtain explicit opt-in for G1–G4 in `HARDWARE_VALIDATION.md`. Idle dimming
   while preventing display-off and actual internal-panel shutdown remain
   unresolved. No synthetic input, private brightness API, overlay, or blanket
   external-display blanking was used. Present measured alternatives to the
   owner if the requested G1 behavior is unavailable safely.
4. Measure the specified ten-minute CPU, combined physical footprint, and
   click-to-pending budgets; instantaneous RSS/CPU readings do not prove them.
5. Supply the real Apple Team/Developer ID identity, notary profile, protected
   Sparkle key pair, GitHub repository and Pages feed. Configure the private
   security reporting route and finalize versioned release notes. Then perform
   G5 from a prior signed build, including tamper rejection, active-session
   deferral, helper replacement, launch Off and uninstall.

The next action is the remaining accessibility/appearance pass, followed by
explicitly approved hardware validation. Public release remains a separate
explicit approval after all applicable evidence has been retained.

## Native follow-up — 2026-09-21

Owner and reviewer: Astra lead. Tested source: `a2ea6ed` (includes the
accessibility fix `74f9710`). No additional reviewer or implementation agent
was used for this focused pass. Environment remained macOS 27.2 (26B5086k),
Xcode 27.0 (27A5252f), arm64.

The original temporary build was gone. An untracked `Runtime/PMSetDriver 2.swift`
was present on resume and differs from the tracked driver. It was preserved,
excluded from commits, and excluded from validation by extracting `git archive`
to a disposable directory and copying only the two reviewed UI edits there.
The validated source matches the tracked application at `a2ea6ed`; this is not
proof that a direct build including that untracked duplicate succeeds.

Live computer-use interaction and screenshots of the actual Debug app used
`LIDPILOT_UI_TESTING=1` throughout. The preview badge was visible. Tests covered:

- All three mode cards, Off/start/stop, and active mode switches without resetting
  the countdown. Preset durations and the More menu were disabled while active.
- 30m, 1h, 2h, 4h, a typed 45-minute custom duration, the native date/time picker
  with keyboard edits, and an indefinite session. These were activation/UI
  checks, not waits for each complete duration.
- Return to stop, Return to acknowledge onboarding, Escape to dismiss a native
  menu, and Command-Q during a mock session. The process exited with code zero;
  relaunch began Off with the duration preference retained.
- Mock Stop & Sleep returned to Off; the real Mac was not asked to sleep.
- All five Settings sections, inactive versus active safety/default locks,
  10/20/30 percent cutoff choices, disabled unsigned helper mutations, and the
  unavailable publisher-update state. No helper or login registration occurred.
- Diagnostic preview, native Save dialog, and a local report written to
  `/private/tmp/LidPilot-native-20260921.txt.txt` (the Save dialog appended its
  extension). The report contained mock session events and status; no transmission.
- Native dark-appearance panel, menu-bar popover, settings, and onboarding
  screenshots. No system appearance/accessibility settings were changed.

Two defects were fixed and rechecked in the running app:

1. Grouped status readings omitted individual field names from the tool-visible
   accessibility text. Each visual label/value row now has an equivalent text
   accessibility representation. The final tree reads, for example,
   `Power: external Lid: open Thermal pressure: nominal System assertion: off
   Display assertion: off`. Spoken VoiceOver remains unverified.
2. The native onboarding window compressed and truncated explanatory text.
   It now takes its natural content height; a final native screenshot shows the
   complete introduction, brightness caveat, and safety/update paragraph.

Debug and Release were rebuilt after the final changes. Both pass strict deep
ad-hoc signature verification. The 51 Runtime and 21 Core tests passed again;
these modules were unchanged by the UI fixes. The final actual-app mock smoke
passed activation, cleanup, rendering, and normal exit. Project/release-script
and signed-update fixture validation was rerun. Logs are disposable files named
`/private/tmp/lidpilot-native-{tests,verify,final-debug,final-release,final-smoke}.log`.

The Mac briefly locked during the pass, and native automation failed despite
locked-use being enabled. The user unlocked it and testing resumed. Hardware,
real helper authentication/recovery, signed updates, performance budgets, and
macOS 15 runtime compatibility remain open; no claim was upgraded from mock
or UI evidence to physical/release evidence.

## Incremental history

The repository began empty and all work is on `dev`. Feature/fix commits cover
scope, design gallery, Core sessions, safety, protocol, observation/journal,
helper leases, typed health, website, bounded execution, recovery retries,
authentication/admission, assertions, reconciliation, icon, unverified status,
native UI, Sparkle, diagnostics, app lifecycle, project/CI, release tooling,
and documentation. Use `git log --reverse --oneline` for the exact immutable
commit list; the final response records the reviewed repository revision.

Implementation and product-documentation commits at this checkpoint:

```text
7e692b3 docs: establish LidPilot scope and implementation plan
04f109b feat(design): add interactive LidPilot concept gallery
520bfee docs: record approved mode-card direction and implementation ownership
5479358 feat(core): model modes and immutable session deadlines
ee7e1aa feat(safety): enforce battery thermal and power policies
4cff471 feat(helper): define bounded versioned XPC messages
28c3294 feat(runtime): observe power state and persist secure recovery intent
9659f76 feat(helper): enforce leases watchdog safety and durable recovery
c40b115 feat(protocol): report typed helper failures and health
deee022 feat(site): add accessible GitHub Pages landing page
0836d0a fix(helper): fence and bound privileged child execution
2944199 fix(recovery): distinguish mutation phases and retry settled commands
c0fd263 feat(xpc): authenticate peers and bound helper request admission
e31a33d feat(power): manage verified expiring app-scoped assertions
ddae49b feat(sessions): reconcile modes with stop safety and update barriers
5bce32e feat(design): add original native app icon assets
a1108f2 fix(status): distinguish unverified helper reads from confirmed Off
9f3bad9 feat(ui): add native mode cards timer settings and onboarding
1c4ddab feat(updates): gate Sparkle installation on verified cleanup
ab182ae feat(diagnostics): bound redact and expire local event logs
5db7561 feat(app): wire native lifecycle approval notifications and safe quit
05e7f3a build: add reproducible arm64 app helper project and CI
34975d0 build(release): validate signed updates and notarized packaging stages
56a44e8 docs: add product contributor and security guidance
```

The final technical-documentation commit records this evidence without changing
application source; its exact revision is reported in the task completion.
