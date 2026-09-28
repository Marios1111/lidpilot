# LidPilot verification

## V1.1 / V2.0 implementation — September 28, 2026

**Unreleased 2.0.0 (build 13)** implements the updated blueprint's V1.1 and
V2.0 scope, including Settings and menu-bar polish. Exact tested source:
**1c19c9084109b2e70de474f52ba18517f4b3404b** on `dev`. The documentation
commit recording these results follows that source commit. No push, release,
helper installation, production update, or physical power test was performed.
The published V1 record below remains separate evidence.

### Completed checks

| Check | Result and scope |
| --- | --- |
| Automated tests | **139 PASS:** 90 Runtime, 34 Core, 15 hostless app tests. `scripts/test.sh` and `scripts/test-app.sh`; zero failures. |
| Builds | **Debug and Release PASS** through `scripts/build.sh`. App, helper and embedded CLI compile. Deep/strict local signature verification passes; these are ad-hoc builds, not Developer ID/notarized release evidence. |
| CLI/app integration | **PASS** with the actual Debug app and embedded CLI using isolated mock power controls. Confirms local IPC, overlapping manual/command/agent requests, continuation and subtask ordering, Stop/disarm, diagnostic privacy, export conflicts, exit status, terminal input/Ctrl-C, and reversible CLI/hook configuration in temporary directories. |
| Heartbeat under hook traffic | **PASS:** `python3 scripts/smoke-cli.py --sustained-hooks` delivers events continuously for 65 seconds without status polling; the helper lease stays active. |
| Native rendering | **PASS:** `scripts/smoke-ui.sh` renders 18 native mock captures, confirms activation/cleanup and normal exit. Settings and task panels were visually reviewed in light/dark. Captures are in `build/native-previews/`. |
| Static/project/release fixtures | **PASS:** `scripts/verify.sh` and `git diff --check`. Includes generated-project consistency, release metadata, cryptographic tamper fixtures, stable/RC Pages fixtures and Homebrew metadata checks. No public artifacts were changed. |
| Focused review | Lead reviewed worker changes and final integration. Independent Sol review covered workload arbitration, helper lease replacement, CLI/IPC and command supervision; its findings were fixed. A focused follow-up found no remaining heartbeat scheduling issue. |

The review corrections preserve a fresh deadline after manual expiry, independent
system/display assertion timeouts, and same-owner helper replacement sampled
against a fresh clock. Uncorrelated Claude completion cannot cancel a newer
turn. Hook traffic preserves an already scheduled heartbeat. The embedded CLI
is named `lidpilot-cli` so it cannot overwrite `LidPilot` on case-insensitive
macOS volumes.

### Remaining native and release gates

- **Native interaction/accessibility:** the mock window's accessibility tree was
  inspected. A preview Settings-opening issue was corrected and rebuilt, but
  macOS then remained locked, preventing the final native click-through.
  Live global-shortcut delivery, VoiceOver and exact interaction latency have
  not been established for this source. Rendered captures do not prove them.
- **Signed helper and hardware:** protocol 2, overlapping closed-lid requests,
  safety/lease recovery and build-12-to-13 replacement still require the explicit
  opt-in procedures in [Hardware validation](HARDWARE_VALIDATION.md). No physical
  panel, closed-lid continuity or new performance result is inferred from mocks.
- **Agent gate G6:** Codex 0.154.0 and Claude Code 2.1.112 adapters are experimental.
  Allowlisted lifecycle fixtures and local hook delivery pass; complete live
  agent acceptance is unperformed. Claude main-turn events without correlation
  cannot shorten the latest turn safely, so the bounded missing-event policy
  releases that request as unknown. See [Developer tools](DEVELOPER_TOOLS.md).
- **Distribution:** signed/notarized packaging, real Homebrew/Sparkle ownership
  and upgrade/recovery acceptance remain release gates. The public download,
  update feed and tap still describe V1; no V2 publication is claimed.

Local check logs were retained under `/private/tmp/lidpilot-v2-*.log`. They
supplement the recorded commands/results, and are not committed release assets.

## Retained V1 release verification

Updated September 27, 2026. Stable **1.0.0 (build 12)** is published.
Source/tag: **af6adf78d4fa776e578132b3111dae11bee536ef**. Later documentation
and website commits do not change the shipped binary source.

[GitHub Release](https://github.com/Marios1111/lidpilot/releases/tag/v1.0.0) ·
[Product site](https://lidpilot.app/) ·
[Stable signed feed](https://lidpilot.app/updates/appcast.xml) ·
[Homebrew tap](https://github.com/Marios1111/homebrew-tap)

The owner explicitly authorized the V1 production exception after reviewing the
prepared artifacts. This ledger retains evidence levels and accepted boundaries;
publication alone is not treated as proof. Final stable cleanup, actual Homebrew
installation/removal and restored native Off state have now passed. No retained
mandatory V1 release blockers remain within the owner-approved support boundary.

## V1 release gates (retained)

| Gate | Status | Evidence and boundary |
| --- | --- | --- |
| G1 display | PASS within accepted contract | Manual/ambient brightness preserved; display availability and normal Off dim/sleep observed. Independent idle dimming while preventing display sleep is an accepted unavailable behavior. |
| G2 lid/work continuity | PASS within built-in-only support | Follow Lid and Keep Mac Running timestamp workloads continued; operator observed darkening after approximately one minute and normal reopen. Electrical shutdown and universal timing are not claimed. External/dock/virtual cases are deferred. |
| G3 recovery | PASS with recorded live/injected boundaries | Real GUI/helper crashes, restart, lease expiry and deadline cleanup; final RC11 GUI crash restored by first 1.040348 s sample and recovered UI Off. Unsafe OS faults and stale/read-back/race paths retain deterministic injection labels. Failed-kill/unreaped-child test verifies the real retained fence and eventual child cleanup. |
| G4 signed helper/XPC | PASS with deferred independent evidence | Exact Team ID/bundle identity enforcement; real publisher/wrong-ID/ad-hoc/malformed/console-user tests and signed ServiceManagement approval. Separate-Team client testing is deferred by owner acceptance, never represented as tested. Stable launchd helper reports parent build 12. |
| Performance | PASS revised V1 gate | RC10 uninstrumented 600.002135 s capture: inclusive 0.799277% CPU; 72.262662 MiB mean / 72.392181 MiB maximum. Safety semantics retained; no sustained runaway indicated. Not a new build-12 measurement. |
| UI/accessibility | PASS retained native checks | Keyboard, user-assisted VoiceOver, Light/Dark, contrast/transparency/motion checks, native Copy Status and temporary Settings Dock/Cmd-Tab verified. Exact click-to-visible 100 ms is unmeasured and explicitly accepted as a post-V1 optimization goal. |
| G5 release/update | PASS | Signed RC1→2→3→4 and RC11→stable build 12 installed. Stable launched Off with replacement helper build 12. Final native login/helper/GUI cleanup, reversible app removal, actual Homebrew installation/uninstall/restoration and restored native Off all passed. |
| Site/domain | PASS | Stable Pages deployment; public signed feed hash matches local manifest; HTTPS enabled, HTTP→HTTPS and www→apex verified. Published Homebrew copy button matches the command; no overflow/console errors observed. |

## Exact source checks and artifacts

- **101 automated tests PASS:** 70 Runtime, 21 Core, 10 actual app coordinator tests.
- Local Debug test build and fresh Release archive/export PASS. The first
  sandboxed app-test attempt was denied cache access before tests ran; the
  normal-access retry passed.
- [Exact final-source CI PASS](https://github.com/Marios1111/lidpilot/actions/runs/36286833754):
  Debug/Release, tests, profile fixtures and static/release validators.
- Release tooling correction aligns validation with the already-tested Standard
  helper scheduling class and extracts only the stable notes section. It changes
  no runtime behavior. Its focused regression rejects the obsolete class.
- Developer ID Team **L69774LN97**, exact production identities, arm64 only,
  hardened runtime and secure timestamps verified. Gatekeeper accepted the app
  as **Notarized Developer ID**.
- App notarization **69a0390d-fec3-4794-b5cc-1fd342afe2a2**: Accepted.
  DMG notarization **a3225609-195c-4aa7-80de-36fe7c816ed5**: Accepted.
  Both stapled and staple validation passed.
- DMG **3,991,611 bytes**, SHA-256
  `ef4b33a5009a6415221bf35a7c009737439d92db451aac794bbecc787f275fbb`.
- Update ZIP SHA-256
  `44e8840d87dfee6a95fa82bc9276035fded571c529ff4dd4b941b20428be749b`.
- Signed feed/notes/archive verified; exact archive accepts its signature and
  altered bytes are rejected. All public Release assets were fetched and checked
  against the manifest. Stable feed SHA-256
  `df0c9f9d6e3ea8686975ec51e3c2bbed55c575c09f98f910f7fad5b4d449c8ee`.
- [Stable Pages deployment PASS](https://github.com/Marios1111/lidpilot/actions/runs/36287189336).
  The first attempt was blocked by a dev-only environment allowlist; main was
  explicitly added, without broadening to all branches, under the publication exception.
- Tracked credential-pattern scan found no matching private keys/tokens. This is
  bounded scanning, not a universal guarantee. Protected signing inputs remain
  outside Git. The previously disclosed local profiling-output incident remains
  documented in the RC11 record; raw trace metadata was not published.

## Performance and accepted goals

| Metric | Recorded RC10 result |
| --- | ---: |
| App CPU | 0.135664% |
| Helper CPU | 0.080696% |
| Child CPU | 0.582916% |
| Inclusive CPU | 0.799277% |
| Interrupt wakeups | 1.181662/s |
| Package-idle wakeups | 0.158333/s |
| Largest five-second CPU interval | 3.412561% |

The V1 owner-revised limits are ≤1.0% inclusive CPU and ≤75 MiB combined physical
footprint over the installed 600-second measurement, with safety guarantees intact.
≤0.2% CPU and exact 100 ms input latency remain post-V1 goals. The UI capture found
no potential hangs and a largest recorded SwiftUI update group of 47.626292 ms;
that is rendering evidence, not physical click latency.

## Retained records

- [Native, brightness and signed release checks](validation/2026-09-21-native-and-release.md)
- [Lid, leases and recovery](validation/2026-09-23-closed-lid-and-lease.md)
- [Owner support/contract decisions](validation/2026-09-25-audit-closeout.md)
- [Real performance acceptance](validation/2026-09-27-rc10-validation.md)
- [Runner fault coverage](validation/2026-09-26-fault-coverage.md)
- [Actual updater coordinator fault tests](validation/2026-09-27-updater-fault-tests.md)
- [Development/production coexistence](validation/2026-09-27-helper-coexistence.md)
- [Notification presentation](validation/2026-09-27-notification-presentation.md)
- [RC11 native, crash and sleep evidence](validation/2026-09-27-rc11-validation.md)
- [Retained orderly uninstall](validation/2026-09-27-uninstall.md)
- [Final stable removal and Homebrew installation](validation/2026-09-27-v1-uninstall-homebrew.md)
- [Historical checkpoints](VERIFICATION_HISTORY.md)

The validated hardware is the recorded M4 MacBook Air/built-in display on its
recorded beta macOS host. macOS 15 CI is build/test evidence, not physical testing.
Notifications reached Notification Centre; banner/sound are OS-controlled and were
not independently established. No analytics, private brightness APIs, fake input,
blanket external-display blanking or V1.1/V2 control features were added.

## Final Homebrew and removal result

The published cask passed `brew style`; `brew fetch` downloaded and verified the
real stable DMG. The earlier noninteractive adoption attempt failed at an
administrator `chmod` prompt and rolled back. It is superseded by the successful
fresh install below; no adoption success is fabricated.

Through stable native Settings: launch at login disabled, helper removal confirmed,
then status **Not installed / Off / override off**. The app quit normally; launchd
lookup returned 113, no LidPilot GUI/helper process remained, and SleepDisabled
stayed 0. The stopped app was reversibly moved to local rollback storage.

The exact public `brew install --cask Marios1111/tap/lidpilot` completed, installing
build 12 into Applications without an administrator prompt. Signature, staple and
Gatekeeper checks passed. `brew list --cask --versions lidpilot` reported 1.0.0.
Actual `brew uninstall --cask lidpilot` then removed the app, with no helper or
login registration to abandon and SleepDisabled still 0. The same public install
command restored the app successfully.

Native restored Settings confirmed **Approved helper / Off / override off**.
Launch at login was restored On; Keep Screen On / two hours / notifications Off
were preserved. Independent final read-back: SleepDisabled=0, no LidPilot wake
assertion, exactly one GUI, one production helper with parent build 12, no
running development instance. Preferences/diagnostics and unrelated global state
were preserved. Historical Background Items rows and rollback bundles are not
running apps and were not deleted.

`brew audit` remains **unperformed on this host** because Homebrew rejects its
outdated Command Line Tools before auditing. No toolchain or security check was
bypassed. This is deferred packaging-tool evidence, separate from the passing
real cask installation/removal, style, hash and Gatekeeper results.
