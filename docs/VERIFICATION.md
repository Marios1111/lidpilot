# V1 release verification

Initial checkpoint: 2026-09-19; native follow-up and release validation: 2026-09-21.
Source and local development builds are implemented; stable release remains
blocked by the gates below. The repository is now
[Marios1111/lidpilot](https://github.com/Marios1111/lidpilot), with `dev` connected
to `origin/dev`. Historical sections below describe their own dated checkpoints.
The latest public prerelease is [RC4](https://github.com/Marios1111/lidpilot/releases/tag/v1.0.0-rc.4),
available for supervised testing through the [product site](https://lidpilot.app).
RC5 and RC6 are local diagnostic candidates. See the current gate table below,
the dated records in `validation/`, and [V1_RELEASE_PLAN.md](V1_RELEASE_PLAN.md).
No stable release is claimed.

Current release-validation owner: the selected GPT-6 Astra High lead. The initial
implementation/UI owner was Astra Max. GPT-5.6 Luna Max handled
bounded Core, diagnostics, project/release, and documentation work. GPT-5.6 Sol
High performed a focused read-only helper security review. Its command-fencing,
journal-phase, admission, and retry findings were fixed by the lead and covered
by regression tests; it was not a second final reviewer. CodeGraph was used for
focused context, with current source and builds as the final evidence.

## Latest closeout — September 26

The [audit closeout record](validation/2026-09-25-audit-closeout.md) records the
owner's accepted dimming/panel/update limitations and narrowed built-in-display
support. External/dock testing and genuine different-team testing are explicitly
deferred evidence, not failed implementations or claimed passes. Exact signing
requirements remain mandatory. The owner accepts this Mac’s recorded beta OS
as the V1 validation host; remaining mandatory gates are not waived.
The prolonged RC6 diagnostic Save dialog did not starve
renewals; the independent save-file branch still needs confirmation.

Current local checks: **86 tests** (21 Core, 65 Runtime) and Debug/Release builds pass at `4877adb`, including the [bounded EOF runner regression](validation/2026-09-26-runner-eof.md).
Earlier package identity inspection and isolated native smoke checks passed at `3b5a1e6`, including identity isolation, independent failed-read
recovery regressions and native product captures. They do not prove installed
signed-helper coexistence. [CI at `3b5a1e6`](https://github.com/Marios1111/lidpilot/actions/runs/36265171164)
also passed its tests and Debug/Release builds. Latest public
prerelease: **RC4**. RC5/RC6 are local diagnostic candidates. The [uninstrumented installed RC6 baseline](validation/2026-09-26-rc6-uninstrumented.md)
completed 600 seconds and **failed the former 0.2% budget at 0.830470% inclusive CPU** (app 0.355936%,
helper 0.054073%, children 0.420460%); memory passed at 63.32 MiB. Its beta OS
build differs from the earlier instrumented 0.543018% run, so the delta cannot
be attributed to instrumentation alone. These statements supersede historical checkpoint totals below.

## Feature checklist

| Feature | Implementation | Remaining evidence |
| --- | --- | --- |
| Native arm64 macOS 15+ app | Swift 6 / SwiftUI / AppKit menu-bar app, original icon, adaptive Soft Glass mode cards | macOS 15 CI build/tests passed; final installed runtime and release-candidate accessibility regression remain |
| Follow Lid / Keep Screen On / Keep Mac Running / Off | Separate requested/effective/observed state, read-back, generation invalidation | G1/G2 physical behavior |
| Sessions | 30m/1h/2h/4h/custom/until-time/indefinite; immutable hard deadlines; switch preserves deadline | Native preset/custom/until-time/indefinite interaction passed; physical timing remains gated |
| Safety | Thermal protection, 10/20/30% battery cutoff, battery/LPM policies, charger/lid/display/wake observation, explicit restart after pause | Live sensor and workload continuity checks |
| Closed-lid helper | Reciprocal signed XPC, console user restriction, fixed pmset operations, bounded child execution, leases/watchdog, journal and conflict handling | Real registration, identity rejection, GUI/helper crash cleanup, lease expiry and replacement helper verified across RC1–RC3; remaining G3/G4 cases open |
| App lifecycle | Starts Off, login preference, helper approval, onboarding, notifications, verified quit and Stop & Sleep | Real helper approval and crash relaunch Off passed; login/notification/sleep paths remain |
| Diagnostics/recovery | Local redacted bounded logs, export preview, cleanup/repair/removal UI, explicit ambiguous-state recovery | Prolonged Save-dialog renewals passed; deterministic saved-file confirmation and final regression remain |
| Sparkle 2.10.0 | Manual/daily checks, signed feed/notes/archive configuration, active-session barrier, helper replacement and interrupted-update handling | Real RC1→RC2→RC3→RC4 signed upgrades and replacement helpers passed; updater fault paths and uninstall remain G5 |
| Distribution/community | MIT and dependency notices, README, CONTRIBUTING, SECURITY, CHANGELOG, issue templates, CI, staged signed/notarized DMG tooling | Developer ID, private reporting, signed/notarized RC1–RC4 and public artifact hashes verified; stable release still gated |
| Website | Static accessible Pages site, no trackers or build dependency | Manual RC publication passed; hosted signed feed bytes/signature verified |

No CLI, AI-agent detection, process automation, Shortcuts, widgets, remote
control, cloud account, or Homebrew feature was added.

## Initial implementation checks — September 19–21

Environment: Apple Silicon; macOS 27.2 (26B5086k); Xcode 27.0 (27A5252f).
The project targets macOS 15.0, but this newer development environment does not
establish support on macOS 15 or constitute a stable-OS release matrix.
On September 26 the owner accepted passing installed tests on the current Mac
as the V1 validation basis; a separate stable-OS installation is not a release
prerequisite. Actual OS versions remain recorded, and the failed inclusive CPU
gate is not waived by that decision.

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

## Initial development artifacts and commands

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

## Current release gates

**Owner revision — September 26:** V1 CPU acceptance is now **≤1.0% of
one core**, including app, helper and children over the same installed 600-second
measurement. Memory remains **≤75 MiB**. No sustained busy-loop/runaway behavior
is acceptable, and safety/verification/watchdog/lease/fencing/conflict/recovery
semantics must not be weakened. Record wakeups and UI response. Finish the
bounded runner/UI checks and one final clean uninstrumented measurement before
marking performance PASS. The old ≤0.2% budget becomes a V1.1/post-V1 goal.
Historical FAIL labels below refer to the requirement in force when measured.

The [RC4 performance investigation](validation/2026-09-24-performance-investigation.md)
tracks the inclusive CPU profile and public read-back research. The
[installed diagnostic RC5 record](validation/2026-09-24-rc5-profile.md) adds a
complete 600-second instrumented run: **FAIL 0.614% inclusive CPU**, with 148
reads attributed to scheduled watchdog (60), renewal admission (44), and fresh
reply verification (44). The [RC6 scheduling candidate](validation/2026-09-24-rc6-scheduling.md)
completed another 600-second installed run: **FAIL 0.543% inclusive CPU**,
144 verified reads, and verified Off cleanup. The owner
reconfirmed that external-display/dock hardware and a separate signing-team
identity are unavailable. The September 25 owner review defers these cases
under the explicit support and security-evidence conditions recorded above.

| Gate | Current evidence | Remaining mandatory work |
| --- | --- | --- |
| G1 display | PASS for Keep Screen On/Off on the recorded built-in display: manual/ambient brightness, two-minute idle observation, cleanup | Complete remaining mode/power/support-matrix observations; independent idle dimming is a documented limitation |
| G2 closed lid | Follow Lid and Keep Mac Running workloads continued through recorded closed-lid intervals; operator saw the built-in screen darken and normal reopen | Owner-approved built-in-only V1 support; external/dock cases deferred, not passed. Immediate or electrical panel shutdown is not claimed |
| G3 recovery | RC1 GUI SIGKILL restored the override within 0.28 s. RC2 lease expiry restored it by 64.7 s and the GUI paused without false Recovery; root-helper crash/restart restored it by the first changed 22.9 s sample. RC3 one-minute deadline ended Off; RC3 GUI SIGKILL restored the override by the first changed observer sample, with no re-enable through 90 s | Inspect RC3 post-crash UI; remaining safely reproducible read-back/restore failures and delayed/race paths |
| G4 identity/helper | Signed/notarized helper registered through ServiceManagement; publisher accepted, wrong-ID/ad-hoc and wrong-console clients rejected by explicit XPC logs; four malformed-wire cases rejected. RC2–RC4 replacement helpers acquired the override; launchd reported RC4 parent bundle version 4 | Genuine different-team test deferred by owner review; preserve exact signing requirements and complete remaining lifecycle matrix |
| Performance | Off 600 s: 0.102% CPU, 47.62 MiB mean; Keep Screen On 600 s: 0.079% CPU, 37.32 MiB mean on RC1. RC3 Keep Mac Running 600 s: **FAIL 0.855% CPU**. RC4 Keep Mac Running 600 s: **FAIL 0.684% CPU**, PASS 38.04 MiB mean; 0.519% CPU came from reaped fixed `pmset` children. Diagnostic RC5: **FAIL 0.614%**, 148 reads; RC6 Standard: **FAIL 0.543%**, 144 reads, 0.363% child CPU, 52.56 MiB mean. Uninstrumented source-matched RC6: **FAIL 0.830470%**, app 0.355936%, helper 0.054073%, children 0.420460%, memory 63.32 MiB mean; beta OS build changed | Final clean uninstrumented ≤1.0% CPU / ≤75 MiB acceptance pending after bounded runner/UI checks; record wakeups/UI timing and verify no pathological behavior. No safety redesign for the old budget |
| G5 release/update | RC1–RC4 are public prereleases with verified hosted hashes. Real Sparkle RC1→RC2→RC3→RC4 installed signed builds 2–4; each relaunched Off with override/assertions released and its replacement helper acquired a new lease. RC3 disabled update checks while active; RC4 canceled check restored its previous helper. Signed archive/feed/notes and tamper rejection passed | Uninstall/cleanup, scheduled-check and interrupted/failing updater paths, final stable candidate |
| Final candidate | Installed diagnostic RC6 build 6 is Developer ID signed, notarized and stapled; its instrumented capture and cleanup are retained. The matching uninstrumented build completed its independent baseline and failed CPU at 0.830470%; memory passed at 63.32 MiB. The last public RC remains RC4 build 4; its signed upgrade, Off relaunch, matching helper lease, canceled-update cleanup and ten-minute measurement were recorded on the host. [Source CI 35905778548](https://github.com/Marios1111/lidpilot/actions/runs/35905778548) and [dev CI 35921628061](https://github.com/Marios1111/lidpilot/actions/runs/35921628061) passed | Revised performance acceptance pending; remaining lifecycle, updater faults, uninstall and stable-candidate checks remain |

The earlier running-controller baseline was resolved through its normal quit
path and independent Off read-back before LidPilot acquired ownership. No
unowned override was cleared. The required signing identity, notary profile
and Sparkle key are now configured; private material remains outside Git.
The prior duplicate driver file was absent at the start of this release pass.
The separate [September 23 record](validation/2026-09-23-closed-lid-and-lease.md)
retains the Keep Mac Running and helper lease-expiry trace hashes.

Stable `main`, `v1.0.0` and the stable update feed are not created while mandatory
gates remain open. RC publication is explicitly authorized and distinct from
stable approval. The complete evidence, exact revisions and artifact hashes
are retained in the linked dated record; historical sections below are not
claims about the current RC's untested paths.

## Native follow-up — 2026-09-21

Owner and reviewer: Astra lead. Tested source: `5507505` (includes the
accessibility fix `e9b7b3e`). No additional reviewer or implementation agent
was used for this focused pass. Environment remained macOS 27.2 (26B5086k),
Xcode 27.0 (27A5252f), arm64.

The original temporary build was gone. An untracked `Runtime/PMSetDriver 2.swift`
was present on resume and differs from the tracked driver. It was preserved,
excluded from commits, and excluded from validation by extracting `git archive`
to a disposable directory and copying only the two reviewed UI edits there.
The validated source matches the tracked application at `5507505`; this is not
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

## Accessibility follow-up — 2026-09-21

The Astra lead owned native testing and final review. GPT-5.6 Luna / Max
performed a bounded source audit, implemented the Settings selection outline,
and removed reference-only documentation at the owner's request. The outline
adds a 1.5-point semantic foreground border only under Increase Contrast;
normal appearance, layout, and selected accessibility traits stay unchanged.
CodeGraph supplied focused source context.

The user explicitly approved temporary system accessibility/appearance changes
and their restoration. The actual Debug app used simulated power controls:

| Check | Evidence and result |
| --- | --- |
| Keyboard navigation | With macOS Keyboard Navigation on, Tab/Shift-Tab reached mode cards, presets, duration menu, custom field/stepper, Start/Stop, footer and Settings; Space activated controls; arrow/Return chose a native menu item; Escape dismissed it. Settings sidebar, safety picker and switch were operable without pointer selection. |
| Focus and selection | Focus rings were visible. Mode selection includes a checkmark and an accessibility selected trait. The Settings outline remained visible when keyboard focus moved to a different section; verified in Light and Dark. |
| VoiceOver | Enabled the real VoiceOver service and completed its first-use dialog without changing the welcome preference. Native navigation was attempted, and the user confirmed “Yes, announcements are clear.” This is user-assisted speech evidence: the automation tool could not inspect the caption window or hear audio directly. It does not establish every VoiceOver rotor or navigation command. |
| Increase Contrast | Native panel/control contrast strengthened. The selected Settings section now has an explicit outline independent of its pale tint. |
| Reduce Transparency | Panel, Settings sidebar and onboarding were opaque. Native materials in Settings/onboarding honored the OS setting without an added fallback. |
| Reduce Motion | Activation, mode changes and timer updates remained usable with Reduce Motion on. Source audit found no authored motion transitions; the visible timer uses a one-second update schedule. |
| Light and Dark | Native panel, Settings and onboarding were inspected; controls and explanatory text remained readable. The final Settings outline was checked in both appearances and disappeared after Increase Contrast was restored Off. |
| Preferred reading size | Inspected Accessibility → Display → Text Size. macOS lists supported apps and system features; LidPilot was not listed. Reading sizes remained unchanged. Automatic preferred-reading-size scaling is not claimed for LidPilot. |

[Apple's caption-panel guide](https://support.apple.com/en-euro/guide/voiceover/unac078/mac)
describes it as the spoken-output display. Apple also distinguishes
[supported-app reading sizes](https://support.apple.com/en-lamr/guide/mac-help/mchld786f2cd/mac)
from [SwiftUI Dynamic Type](https://developer.apple.com/documentation/swiftui/environmentvalues/dynamictypesize),
which does not change text size on macOS. No iOS-only scaling workaround was added.

Restoration was verified in native System Settings: Keyboard Navigation Off,
VoiceOver Off, Increase Contrast Off, Reduce Transparency Off, Reduce Motion
Off, and Dark appearance selected. The caption-panel preference was already
on and was not changed. Reading sizes, brightness and power settings were not
modified. The temporary Settings and VoiceOver Utility windows were closed.
The other closed-lid controller remained running; hardware testing did not start.

Debug and Release compile after the outline change, and the final mock app
smoke verifies activation, cleanup, rendering and normal exit. The earlier
72-test result still covers the unchanged Core/Runtime modules. Native checks
are the regression evidence for this visual-only change. Build/smoke logs are
`/private/tmp/lidpilot-accessibility-{debug,release,smoke}.log`.

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
1e8afab docs: establish LidPilot scope and implementation plan
57acecd feat(design): add interactive LidPilot concept gallery
bdf11e6 docs: record approved mode-card direction and implementation ownership
4fcc20f feat(core): model modes and immutable session deadlines
d102a7f feat(safety): enforce battery thermal and power policies
767ba7c feat(helper): define bounded versioned XPC messages
7685010 feat(runtime): observe power state and persist secure recovery intent
a189b06 feat(helper): enforce leases watchdog safety and durable recovery
9225d2f feat(protocol): report typed helper failures and health
08777f8 feat(site): add accessible GitHub Pages landing page
1df2962 fix(helper): fence and bound privileged child execution
ca19224 fix(recovery): distinguish mutation phases and retry settled commands
047a144 feat(xpc): authenticate peers and bound helper request admission
9147399 feat(power): manage verified expiring app-scoped assertions
52e1a16 feat(sessions): reconcile modes with stop safety and update barriers
94c8f74 feat(design): add original native app icon assets
4a17ac6 fix(status): distinguish unverified helper reads from confirmed Off
0f23db7 feat(ui): add native mode cards timer settings and onboarding
29d046f feat(updates): gate Sparkle installation on verified cleanup
f75a85c feat(diagnostics): bound redact and expire local event logs
07844c2 feat(app): wire native lifecycle approval notifications and safe quit
c52eac1 build: add reproducible arm64 app helper project and CI
5533682 build(release): validate signed updates and notarized packaging stages
98017dc docs: add product contributor and security guidance
```

The final technical-documentation commit records this evidence without changing
application source; its exact revision is reported in the task completion.

## Local history maintenance — 2026-09-21

At the owner's request, obsolete reference-only documentation was removed from
all reachable local history, including Codex checkpoint refs. A disposable
mirror proved preservation of all 30 commits, parent ordering, messages, author
and committer metadata, and all paths except the four approved documentation
files. The current tracked file tree was identical before and after rewriting.
Historical commit identifiers above were refreshed to the rewritten identifiers.

The lead applied the verified rewrite after saving a private rollback bundle
outside the repository. Local recovery objects/reflogs were retained; no GitHub
remote was configured and no remote history, publication, or force-push occurred.
The pre-existing untracked source duplicate remained unchanged.

## RC4 candidate continuation

The [September 24 RC4 record](validation/2026-09-24-rc4.md) records build 4
CI, Developer ID signing, accepted notarization, stapling, signed Sparkle
artifacts and hosted hash verification. Sparkle installed RC4, which relaunched
with its override and assertions off; launchd reports helper build 4. Native
confirmation, a matching-build helper lease, and the ten-minute performance
measurement are now recorded. RC4 reduced inclusive CPU to 0.684% but still
missed the 0.2% target; the stable release gate remains open.

## September 26 continuation checkpoint

The [independent accounting review](validation/2026-09-26-independent-review.md)
confirms the failed measurement; it found no accounting correction that produces
a pass. One presentation-only candidate is being tested on the exact RC6 source
in an isolated worktree. Its native lifecycle must pass before controlled A/B/A
installed measurements. No helper, timer, read-back or recovery semantics change
in that experiment. A UI reduction alone is not promised to meet the full budget.

The 34-second Remotion landscape, vertical and 720p web exports are rendered.
Website integration and playback review remain separate from application gates.
Neither these exports nor source CI authorize a stable release.

## Revised performance closeout checkpoint

The owner explicitly revised the V1 engineering budget; prior raw measurements
and their historical outcomes are preserved. The hidden-presentation candidate
was not merged: a disposable native host missed an actual order-out visibility
event, so its lifecycle was not robustly verified. That hypothesis is closed
for V1. The only remaining targeted CPU fix is a demonstrated command-runner
pathology, if reproduced. After the final clean acceptance passes, stop
performance work and continue the other release gates.
