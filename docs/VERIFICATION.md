# LidPilot verification

## Homebrew upgrade follow-up — September 29, 2026

Preparing the owner's installed upgrade exposed a normal-quit regression in
2.0.0, also present in 2.0.1: `canTerminate` rejected Homebrew/manual ownership
before checking whether any update was pending. Native Settings confirmed the
helper removed, session Off, sleep override off and Launch at login disabled;
Quit nevertheless displayed the pending-update alert with the lid open.

Released **2.0.2 build 17** checks the update barrier before requiring Sparkle
ownership. Actual pending updates still require the existing cleanup/open-lid
checks. All **16 update-coordinator app tests** passed, including normal quit
for all three update methods and blocked/reconciled interrupted updates.
The old app quit normally after temporarily selecting Sparkle, without starting
an update. No new physical-power test was run for this quit-only fix.

Exact tagged/binary source: **a68b5b37aa659fe7a178e21706cb0b63a58c24ac**.
[Final-source CI](https://github.com/Marios1111/lidpilot/actions/runs/36494593689)
passed the package/app tests, static/release checks and Debug/Release builds.
[GitHub 2.0.2](https://github.com/Marios1111/lidpilot/releases/tag/v2.0.2)
contains the verified signed artifacts. App notarization
**12c4c482-6976-4028-a5f3-15aebd050b9b** and DMG notarization
**9295d9b5-f412-4ea0-add0-763d93e12bac** were Accepted. Sparkle signatures,
deep/strict signing, staple validation and Gatekeeper assessment passed.
The **4,566,336-byte** DMG SHA-256 is
`e3209bfb9aeb70d2c560ed3dd47b42deae6182bf4c59deba0a44d8d974fabae6`;
the manifest SHA-256 is
`0f626e3c8abde4cb22c4eac93c74c2f890fa2476d666807015366925ef7c24ea`.

All five public release assets were downloaded and matched the signed release.
The public-byte/signature Pages validator passed, followed by
[Pages deployment](https://github.com/Marios1111/lidpilot/actions/runs/36495208977)
from **9e3ad797a73c290897e189f98e01b817b8733b51**. The live homepage, stable
feed, notes and manifest matched; historical RC4 bytes remain unchanged.
The [Homebrew tap](https://github.com/Marios1111/homebrew-tap/commit/a064e1e)
publishes the matching DMG checksum. Style passed and temporary Homebrew
developer mode was restored Off. The unchanged Command Line Tools audit
blocker from 2.0.1 remains; it was not presented as a passing audit.

After verified native cleanup, `brew update` and `brew upgrade --cask --greedy
Marios1111/tap/lidpilot` upgraded the actual **2.0.0** installation to
**2.0.2 build 17**. The installed bundle passed deep/strict signature,
staple and Gatekeeper validation, and its Homebrew receipt reports 2.0.2.
Native Settings confirmed the restored **Homebrew** update ownership,
**Launch at login On**, helper **Approved**, session **Off**, and sleep override
**off**. The owner's current Follow Lid / **30 min** and notifications On
preferences were preserved. No hooks or local CLI access were enabled.
The native tool timed out when delivering the final Quit action. The owner
then confirmed that **⌘Q quit without a warning with Homebrew selected** and
that reopening was normal. Installed acceptance is complete.

The two newly generated test/release build-cache directories (approximately
**0.53 GiB**) and one debug app registration were removed. The installed app,
signed release archives, rollback copies and validation evidence were preserved.

## Agent Tasks usability follow-up — September 29, 2026

Stable **2.0.1 (build 16)** is [published on GitHub](https://github.com/Marios1111/lidpilot/releases/tag/v2.0.1).
The requested changes are a
menu-bar agent switch, explicit monitoring/protection states, optional hiding
while off, and native reversible Codex setup. The helper protocol, power policy,
leases, recovery paths, and adapter event/version contract remain unchanged.

Implementation and a bounded Sol High review are complete. The review corrected
duplicate marked-handler detection and setup feedback placement. Package checks
passed **94 Runtime + 34 Core** tests; **15 hostless app tests** passed. The
review-corrected hook suite passed again. Native mock app/CLI integration passed
IPC, overlapping requests, lifecycle fixtures, privacy, Off, exit status, TTY
input/Ctrl-C, and reversible setup. The smoke check now reads the built bundle's
version instead of assuming an old candidate number. A Pages self-test fixture
also needed isolation from newer published release notes; production signature
and latest-only directory checks remain intact.

Final light/dark rendering, static checks and native interaction passed. The
actual mock panel switch enabled monitoring without starting protection; a
projected Codex event displayed one protected task. Switching it off preserved
the manual timer. Set Up opened Agent Tasks directly. Hiding controls removed
them while off, enabling monitoring restored them, and Turn Off All Requests
cleared the mock session. The preview quit normally after verified Off. No new
physical power or paid agent session is claimed. The prior V2 hardware record
applies to unchanged power/helper behavior; fresh performance, live desktop G6
and VoiceOver evidence remain unmeasured. Codex's hook trust step is explicit
and is never bypassed or written by LidPilot.

Exact tagged/binary source: **2690e3b85f874abe68b0e4410245b3564e2a515b**.
[Final-source CI](https://github.com/Marios1111/lidpilot/actions/runs/36492960755)
passed, including Debug/Release builds and the test/static/release checks.
Developer ID app/helper/CLI signatures, hardened runtime, secure timestamps and
Sparkle archive/feed/notes signatures passed. App notarization
**504ec59a-bead-4969-b0dd-b5f41289768d** and DMG notarization
**0f8bc644-22c6-4b6d-93a6-c29c1adfce7c** were Accepted. Staple validation and
Gatekeeper's Notarized Developer ID assessment passed for the app and DMG.

The public manifest and all four GitHub assets were downloaded and matched the
signed local release. The **4,566,270-byte** DMG SHA-256 is
`7c75756a8b8c71e0f5718699089f569c633102130fa25fc7bf05f897d6b2eb00`;
the manifest SHA-256 is
`88cd017955766d423317c7747403ca189a980d12b391ff3a86ab399041f9545d`.
`validate_pages_site.rb --publication stable --verify-public-assets` passed.
[Pages deployment](https://github.com/Marios1111/lidpilot/actions/runs/36493729790)
passed from **0153e06c0c93977b11f26a875ecbaf6ca550a4f8**. The live homepage,
stable feed, notes and manifest match the committed bytes; the historical RC4
feed remains byte-identical.

The [Homebrew tap update](https://github.com/Marios1111/homebrew-tap/commit/56f148d)
publishes the verified 2.0.1 DMG checksum. `brew style` passed; `brew audit` was
blocked before auditing by the host's outdated Command Line Tools. Homebrew's
temporary developer setting was restored Off. The installed Homebrew app was
preserved at **2.0.0 build 15**; no installed 2.0.0 → 2.0.1 upgrade or live
Codex Desktop trust/setup session is claimed. The documented native cleanup
and Homebrew update command remain the supported upgrade path.

The owner's requested debug cleanup removed **21** generated build/test/cache
directories (approximately **3.42 GiB** of allocated data) and unregistered
**six** generated app copies after confirming no process used them. The
installed app, signed release/candidate archives, rollback bundles, hardware
evidence, native captures and the dependency/signing-tool cache were preserved.
Publication and scoped debug cleanup are complete.


## V2 published artifacts — September 29, 2026

Stable **2.0.0 (build 15)** is published at
[GitHub](https://github.com/Marios1111/lidpilot/releases/tag/v2.0.0).
Exact tagged/binary source: **bd611f9e052440915a0e3d34ceca1a5c301c019c**.
[Final-source CI](https://github.com/Marios1111/lidpilot/actions/runs/36486164082)
passed all 140 tests, Debug/Release and static/release checks.

Developer ID Team **L69774LN97**, hardened runtime, secure timestamps and arm64
app/helper/CLI signatures passed. Stable app notarization
**b5374947-8074-4b5a-92b3-ffebe11e83ee** and DMG notarization
**fc143235-ca25-4ddc-97c0-67effdd843dc** were Accepted; both staple validations
passed. Sparkle archive/feed/notes signatures verified, including independent
archive verification against the app's embedded public key. No private key was
exported. The bundle embeds the stable `/updates/appcast.xml` feed and build 15.

- DMG: **4,515,775 bytes**, SHA-256
  `cf3ca1e3052a5947ed2f3627f01b06ae02449440a27d82edba02267cf1f59f60`.
- Update ZIP SHA-256:
  `b30d1df0280f0a37164523738ab9879e19c275d5af70a904c2c4c4f3d0b6b34b`.
- Stable feed SHA-256:
  `678c0e99bf76740df74b3b423263d6a1531d369996c7afde327485a7c177f2e0`.
- Manifest SHA-256:
  `26f9ccf4c3d6261206e10b3170aac4eaf5d01a9d60bee3208ca4acf94cc12489`.

All five public assets were fetched back; the manifest bytes and all four
artifact hashes matched. `validate_pages_site.rb --publication stable
--verify-public-assets` passed public-byte and signature validation. The historical
RC4 feed remains byte-identical. The stable website uses its existing latest-only
feed/notes contract; V1's immutable GitHub release and notes remain available.

The [Homebrew tap](https://github.com/Marios1111/homebrew-tap/commit/afae1e9)
now publishes the exact V2 DMG hash. `brew style` passed. `brew audit` was blocked
before auditing by the host's outdated Command Line Tools; no toolchain change
or bypass was made. Homebrew's temporary developer setting was restored Off.
The test helper was removed through native Settings while Off before the
original V1 bundle/receipt were restored for the actual Homebrew upgrade.
[Stable Pages deployment passed](https://github.com/Marios1111/lidpilot/actions/runs/36487186248)
from website revision **e671bdaf0c5c6764a3dff55fa8ec6620409d8b55**. The live
homepage advertises V2; downloaded feed, notes and manifest match the public
release byte-for-byte. No additional site deployment is needed for later
documentation-only changes.

The exact `brew update` then `brew upgrade --cask --greedy
Marios1111/tap/lidpilot` path successfully upgraded the restored **1.0.0** bundle
and receipt to **2.0.0**. The final installed app is build **15**; deep/strict
signature verification, staple validation and Gatekeeper's Notarized Developer
ID assessment passed. It launched Off and its newly approved helper reported
build **15**, protocol **2**, the expected signing team, healthy read-back,
SleepDisabled=0 and no lease/ownership/recovery pending.

Native final Settings confirmed **Homebrew** update ownership with Sparkle
checks disabled, Follow Lid / two hours, notifications On and restored Launch
at login On. Temporary CLI access was turned Off, the production socket was
removed, all global test shortcuts were cleared, and hooks stayed disarmed.
Independent final read-back confirmed SleepDisabled=0 and no LidPilot wake
assertion. No hook configuration or shell files were installed or changed.
The original V1 and local candidates remain available in local rollback storage.

V2 publication and the authorized installed acceptance are complete. The
experimental G6 adapters, unmeasured fresh V2 performance/new-page VoiceOver,
exact latency, deferred hardware topologies and blocked Homebrew audit remain
explicit evidence boundaries; none is presented as a passing measurement.

## Retained V2 stable preparation — September 29, 2026

Corrected runtime source **ff9ec43c100fd598734784c72ed28665eb329fc9** passed
[CI](https://github.com/Marios1111/lidpilot/actions/runs/36484945346): **140 tests**
(91 Runtime, 34 Core, 15 app), Debug/Release and static/release checks. The focused
Sol review found no material issue with the fix's pending-operation wait or its
Stop/safety behavior. Stable build **15** changes release metadata/documentation
only after this tested runtime. Public V2 publication is still pending.

Build **14** was Developer ID signed and notarized (Accepted submission
**158efdd9-a866-4f1a-a411-96b92682aa78**), stapled, Gatekeeper accepted and
installed with its approved protocol-2 helper. The fresh live overlap check
passed: a 100-second manual Display session plus two simultaneously started
Closed commands; the first command ended at 25 seconds, the second's protection
expired at 60 seconds while its child continued to its normal 75-second exit.
The helper override stayed on while needed, then returned to 0 while manual
Display remained on with its original deadline. At 105 seconds all controls were
Off. Both child commands exited 0. No workload was killed to enforce a deadline.

A subsequent authorized GUI-loss test restored SleepDisabled=0 at the first
**1.045408-second** sample, with no LidPilot assertion remaining. Build 14
relaunched Off, hooks disarmed, with healthy helper build 14. Raw evidence:
`/private/tmp/lidpilot-v2-live-build14/`. The built-in-only closed-lid continuity
and physical observation from build 13 are retained below; no new electrical
panel claim is inferred from the corrected command-acknowledgement path.

The owner requested proportionate checks and proceeding when another test was
unnecessary. No new ten-minute profile was run: a read-only counter probe could
not read the privileged helper without another administrator handoff. V2
performance is **unmeasured**, and the V1 baseline below is not relabeled as a
V2 pass. New-page VoiceOver and exact latency are also unmeasured. G6 adapters
remain experimental, with manual sessions available as the reliable fallback.

The authorized bounded hardware/helper checks are complete on the recorded
setup. Stable artifact signatures/notarization, publication, exact downloaded
bytes and final Homebrew replacement remain the distribution steps.

## Retained V2 candidate validation — September 29, 2026

The owner authorized V2 publication, candidate installation, signed-helper and
upgrade checks, a 60-second closed-lid check, overlapping deadlines and GUI-loss
cleanup. V2 is **not yet published**. Candidate build 13 came from
**400f0b34b4a2666a68303cfc117d11085e76b29a**; its app notarization
**4929c3cc-e057-4707-8b66-75252acb3d1a** was Accepted after unlocking the Mac.
Stapling, strict signatures and Gatekeeper's Notarized Developer ID assessment
passed. The prior locked-Keychain failure was superseded without recreating
credentials. Direct Sparkle Keychain signing independently verified against the
published public key; no private key was exported.

V1's build-12 helper was removed normally while Off before replacing the app.
The signed build-13 app launched Off; its approved helper reported protocol 2,
build 13, healthy read-back, no lease and SleepDisabled=0. The V1 bundle remains
in local rollback storage. Homebrew's receipt remains 1.0.0 during candidate
validation. Launch at login is temporarily Off; local CLI control is temporarily
On. No real agent hook configuration was installed.

Native Settings navigation, diagnostics, update ownership and shortcut recording
were checked. The operator confirmed that the registered temporary Command-Shift-K
shortcut opened the real popover; the panel was visually inspected and its Settings
button worked. The shortcut was cleared. VoiceOver on new pages and exact latency
remain unmeasured. Historical native mock checks remain separately applicable.

On the M4 MacBook Air (Mac16,13, 24 GiB), macOS 27.2 beta 26B5091g, external power,
80% battery and no external display, the operator closed the lid for approximately
60 seconds, observed darkness and reopened normally. Twelve five-second samples
observed closed (25.261–80.194 seconds); the harmless timestamp recorder produced
121 samples with a maximum gap of **1.006319 seconds**. SleepDisabled remained 1
through the closed interval, and automatic cleanup returned verified Off/0. This
is built-in-only continuity and operator observation, not electrical panel proof.

The same live test **failed concurrent command admission**: two `run` calls both
returned 78 while the combined policy was still Starting. No child command was
launched; their abandoned requests expired as unknown without ending the manual
session. A helper-latency regression reproduced the failure. The coordinator now
waits for the superseding combined transition before replying. **91 Runtime tests
pass**, including the new regression and delayed Stop/safety cases. A fresh
signed build 14 candidate is required before accepting the overlap/recovery gates.

[CI at d9165fd passed](https://github.com/Marios1111/lidpilot/actions/runs/36481629740)
for the pre-fix source: 139 tests, Debug/Release and static/release checks. The fix's
final build/CI and new signed overlap/GUI-loss checks are pending. Native build-13
helper removal subsequently confirmed Not installed / Off / override off.

The raw bounded observations are in `/private/tmp/lidpilot-v2-live-20260929/`.
Codex 0.154.0 and Claude Code 2.1.112 adapters remain **experimental** under G6;
live agent acceptance is unperformed. External/dock/virtual display coverage,
independent different-Team testing and new V2 performance measurements are not
claimed. Stable packaging, public assets, Homebrew and the stable feed remain
pending; the public release is still V1.

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

### Initial native and release gates at the implementation checkpoint

- **Native interaction/accessibility:** see the follow-up above for the passed
  native mock checks and the final popover, global shortcut and accessibility
  boundaries. Rendered captures do not prove native behavior.
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
