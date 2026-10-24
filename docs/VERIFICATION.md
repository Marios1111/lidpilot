# LidPilot verification

## Menu-bar automatic-lock choice and local commits — October 24, 2026

Current code revision: **`3afdc12a94c18442de09ecaeea4918a238c1b0ba`** on `dev`.
Runtime/session work is committed as `d4f64ed`; native UI and the popover choice
are committed as `3afdc12`. This validation record is committed separately.
Earlier working-tree hashes and “uncommitted” statements below describe the
retained pre-commit snapshots, not the current Git state. Nothing was pushed,
tagged, notarized or published.

The popover now shows **Prevent automatic lock** directly below the mode
choices. On selects the existing session-only desktop hold for computer use;
Off allows normal locking with the lid closed. It shares its preference with
Settings → General, keeps the default Off for a new installation, and preserves
the owner's current On choice. Configuration remains disabled while requests
or Agent Tasks are active, with an explicit Turn Off instruction. No power,
helper, password, manual-lock or session-deadline semantics changed for this
UI follow-up. **Keep desktop available** in the older evidence refers to this
same preference's earlier label.

Design Toolkit's native SwiftUI route was used. Final Debug build, static
checks, light/dark native rendering and mock cleanup passed. Native mock
interaction verified Off → On, session Start, the disabled active control,
Stop → Off selection and normal Quit. Runtime/Core tests were rerun and passed
**103 + 34**; the retained **16 app tests** cover unchanged app-controller
sources. No new intrusive physical-power test was needed for the view-only
change; the build-19 closed-lid result below is retained for unchanged runtime.

Signed local **2.0.2 build 20** is installed at `/Applications/LidPilot.app`.
Developer ID team `L69774LN97`, hardened runtime, secure timestamps and
deep/strict signatures were verified. The old app/helper were stopped and
removed through native verified cleanup (Off/SleepDisabled=0); the replacement
helper is Approved, build 20/protocol 2, healthy, with no recovery pending.
The owner's prior manual Follow Lid session was restored only for its unexpired
remaining time. Its new continuous deadline was checked not to exceed the
original deadline; it was not silently renewed for another hour. The installed
popover was read back showing the switch On/disabled, active protection and
approximately 47 minutes remaining. Other preferences were preserved.

Installed executable SHA-256:

- App: `59985ca3bd49b915ccba6d796bfb0545ac46e4287400cdba1f321febae527299`
- Helper: `c9e1b64b5e5d0bb5965a1049a3c7f582e759352b2a711213d679cca2c4abc45b`

Build 20 is an Xcode override, keeping repository public release metadata at
2.0.2/build 17. This remains a local signed, unnotarized candidate, with the
Homebrew receipt/public artifacts untouched. Build 19 and its signed archive
remain available for rollback; native renders and local logs remain under the
documented ignored validation/build directories. Manual Lock, physical panel
power and long-duration/other-display coverage retain the limits below.

## Opt-in desktop availability candidate — October 24, 2026

The owner explicitly requested preventing automatic screen locking during
active closed-lid Codex sessions, and accepted that the built-in display may
remain powered. This supersedes the earlier default display-drop behavior
only for an opt-in session policy. Password settings, manual Lock, helper
scope and safety limits remain unchanged.

**Keep desktop available**, in Settings → General, defaults Off and is
configured only while sessions/Agent Tasks are Off. It retains the existing
public idle-display assertion across lid closure for active manual and task
requests. Closed requests contribute to its deadline when opted in; the
60-second renewable lease cap, normal Stop/expiry/safety/update/quit cleanup
and launch-Off behavior remain. No lock-only private API, input simulation or
password-preference change was added. It cannot unlock an already locked Mac.

Apple documents that the display assertion prevents idle display sleep, but
lid closure and other causes can still sleep the display. Therefore native
closed-lid anti-lock success and physical panel state require observation.
The option targets the exact display-idle lock path identified below; it is
not a guarantee against every OS or managed security policy.

Current source is uncommitted on `dev`, base
`f55d6f7fdee4fb29900afde87ee3fad303559dfe`. Tested code diff SHA-256
(`git diff --binary -- App Runtime Tests scripts/smoke-ui.sh`):
`ae4c5fb7ad158e8fbd3fa92ce84c458f6ea09b0830789c6688866311c80af205`.
**103 Runtime + 34 Core + 16 app tests** pass. Focused read-only review found
no actionable issues with the new preference, deadlines, cleanup or helper
boundary. Debug and Developer-ID-signed optimized Release build **19** passed,
as did static checks and expanded native mock rendering/cleanup. Native mock
interaction verified the switch, selected/active status, activation, disabled
configuration during a session and normal Quit cleanup. Mock CLI/app IPC
integration also passed. No public release is authorized.

Signed build-19 executable SHA-256:

- App: `d5cb4fea772cb895862f153bf67038b4112c541a980ba65ad53ecae32ca20809`
- Helper: `d9a866a669b4478cfe4c63a515c85cb1ef7038644066871fd418612f60cbd297`

Publisher team `L69774LN97`, secure timestamps, hardened runtime and deep/strict
signatures verified. This is a local signed, unnotarized candidate. Build 19 is
an Xcode override; the repository release metadata remains 2.0.2/build 17.

Build 19 is now installed in place, with build 18 preserved for rollback.
The owner explicitly confirmed enabling **Keep desktop available** and the
native switch was turned On while Off. The replacement helper is Approved,
build 19/protocol 2, with healthy journal, power read-back and watchdog status.
The external-power/open-lid baseline had SleepDisabled=0 and no owned lease
or recovery pending before the approved bounded test.

On Mac16,13 with 24 GiB RAM, macOS 27.2 (26B118), external power and no external
display, a four-minute Follow Lid session began at approximately **21:24:16
Athens time**. Both system/display holds and the owned override were verified.
Read-only sampling recorded 240 timestamps over 239.754 seconds, with a maximum
gap of **1.054 seconds**. Lid closure appeared in the macOS log at 21:25:24;
five-second lid sampling recorded **170 consecutive closed samples spanning
169.507 seconds**, all with SleepDisabled=1. No display-dim lock request or
locked-session event appeared during the active test interval. Codex continued
issuing the read-only sampling/log tools while the lid was closed; no app status
poll was used to renew protection during that interval.

The timer then expired normally. App/helper status and independent read-back
confirmed **Off, both assertions off, SleepDisabled=0, no lease/ownership or
recovery pending**. The preference remains enabled for future sessions; the
preference alone holds nothing while Off. Subsequent macOS logs show a
display-dim lock at **21:29:25**, after that test deadline, and reopening at
21:29:28. This establishes that ordinary automatic locking resumed after the
hold ended, rather than an in-session failure.

The owner then started a normal one-hour Follow Lid session at **21:29:47**
and closed the lid at **21:29:50**. A second read-only recorder captured 120
samples from 21:31:10–21:33:09, spanning **119.385 seconds**, all closed with
SleepDisabled=1; the largest gap was **1.072 seconds**. No automatic-lock event
appeared after that session started. Native accessibility reading and native
window capture both remained available while the lid was observed closed,
and Codex continued issuing tools. The owner subsequently confirmed:
**“ok now it worked. it did not locked”**. This is a passing bounded closed-lid
automatic-lock/desktop-availability check on the recorded setup.

The existing one-hour session is preserved, with the preference enabled,
healthy helper ownership and no recovery pending. It is not automatically
extended or converted to indefinite operation. Physical backlight state,
manual Lock and long-duration/other-display configurations remain unverified;
no claim of electrical panel shutdown or universal workload compatibility is
made. No manual Lock path or password preference was changed.

Raw continuity, baseline/started/after-timer status and filtered lock events
are retained in `release-private/local-validation/2026-10-24/desktop-hold/`.
The signed candidate and original build-17/build-18 rollback archives remain
under the same ignored local validation folder. No commit, push, notarization
or publication was performed.

## Local lock/display investigation and native polish — October 24, 2026

### Live follow-up at 21:09–21:13 Athens time

The owner reports continued locking and confirms a connected power cable.
Fresh native helper/app status confirms **external power**, charging at 53%,
Follow Lid active, both assertions on with the lid open, and a healthy owned
build-18 helper lease with `SleepDisabled=1`. The current one-hour session began
at 20:49:51; it had not expired or paused when inspected. No power controls or
settings were changed during this follow-up; the owner's active session was
preserved.

Read-only macOS login/power logs identify this lock trigger: lid closed at
20:49:59, then `LWDisplayWillSleepCallback` at 20:51:22, followed by
`kLWLockFromDisplayDim` and the locked-session notification. An unlock completed
at 21:09:00. The power log retains LidPilot's system-sleep assertion through
this interval and shows no new system Sleep entry between the current session's
start and the inspection. This supports **display sleep triggering macOS lock
while system keep-awake remained active**, rather than a charger-triggered
LidPilot safety stop. It does not prove physical backlight behavior or Codex
workload continuity. The earlier helper-contention fix did not fix or change
this macOS lock policy. Password/lock settings remain unchanged.

For desktop automation that requires an available unlocked display, the
supported existing mode is Keep Screen On with the lid open. Closed-lid work
remains suitable only for workloads that tolerate the locked/unavailable
desktop. Physical panel-off validation remains pending.

### Earlier local implementation and installation evidence

Local changes are based on `dev` at
`f55d6f7fdee4fb29900afde87ee3fad303559dfe`, uncommitted and unpushed.
The tested source diff over `App`, `Runtime`, `Tests` and `scripts/smoke-ui.sh`
has SHA-256 `38202394b2351804cc60603241167956af17866caf606dc15d99f6093c89b15b`
(`git diff --binary -- App Runtime Tests scripts/smoke-ui.sh`).

The owner initially reported Follow Lid leaving the built-in display lit when
closing it, then finding macOS locked when reopening later. At the initial
inspection the cause was **unconfirmed**. Retained local diagnostics showed several sessions ending at
their selected 30/60-minute deadlines, but cannot tie one to the reported
incident. Ordinary lock is not a runtime safety predicate. User-session
resignation still stops protection; it must not be reinterpreted as proof of
ordinary screen locking. The app preserves macOS password/lock policy and
cannot guarantee desktop automation behind a locked or unavailable display.
No physical panel-off conclusion follows from the helper flag or assertions.

One confirmed defect was concurrent Off-state inspections: the retained
2,000-entry local log snapshot contained 1,164 unverified entries and 789 Off
entries, including repeated helper-busy responses milliseconds apart. Off
inspections now coalesce and use the existing operation queue, preventing
contention with Start/Stop. Delayed success/error responses cannot overwrite
newer state. Regression checks cover 30 concurrent refresh calls producing
one inspection, later refresh admission, Start serialization and Stop races.
System-sleep and active-user-session-change stops now have distinct reasons.

Design Toolkit selected macOS SwiftUI patterns. The native interface exposes
Until I stop directly, labels confirmed active modes separately from selection,
clarifies countdown endings, refines settings/help and documents desktop lock
limits. Only visible finite sessions create a periodic countdown schedule;
hidden and indefinite sessions use static text. No fresh energy/CPU reduction
percentage or ten-minute active performance pass is claimed. A read-only
20.0008-second sample of the **old installed build 17, app only, Off** measured
0.00124% inclusive CPU of one core and 61.52 MiB physical footprint. Its
three-second stack sample was idle; this is not an active app/helper gate or a
before/after benchmark.

Validation passed with exit 0: **98 Runtime + 34 Core + 16 app tests**,
Debug and optimized Release builds, static/project/release self-checks,
expanded native mock captures (including custom/until/indefinite/paused states),
mock activation/cleanup and CLI/app IPC integration. Actual isolated native
interaction verified indefinite Start, mode switching with the end condition
preserved, Off, More → Custom, Return-key Start, a decreasing finite countdown
and Settings → Agent Tasks. Light/dark rendering was inspected; a duplicated
menu chevron was corrected. VoiceOver and fresh accessibility-settings
combinations remain unverified. Preview Quit exited 0 after verified Off;
its final AX read timed out because the app had exited.

With explicit owner approval, **2.0.2 local build 18** was built using the existing
Developer ID identity, with build 18 supplied as an Xcode build-setting override;
the repository's public release version/build remain unchanged. The original
app and preferences were backed up, the old helper was removed through native
Settings, and the new app was installed in place at `/Applications/LidPilot.app`.
The owner separately authorized helper removal/re-enabling after automatic
approval review required exact authorization. The replacement helper is
Approved, build 18, protocol 2, with healthy journal/read-back/watchdog status.
Deep/strict signatures, hardened runtime, signing timestamps and publisher team
`L69774LN97` were verified. This local candidate was **not notarized or published**;
the Homebrew receipt and public assets were not changed.

Installed executable SHA-256:

- App: `a08753498e713bf4334f220ac6c1911cebdb8a3b7a2f64baf3f1a6582fe7d93b`
- Helper: `c04b5a93f2d09d83294820842f91a80e9f4e16a67c3a657ea4c839702edc58f5`

The owner approved a two-minute plugged-in physical check, but could not connect
a charger at the time. The helper's baseline reported battery power at 55%,
nominal thermal state, Low Power Mode off, lid open and no external display.
**No real keep-awake session or closed-lid experiment was started.** Physical
backlight, locked-desktop behavior, long-session continuity and fresh active
performance remain pending. Final independent read-back confirmed
**Off, SleepDisabled=0, both assertions off, no lease, no ownership and no
recovery pending**.

Rollback archive, preferences and signed candidate are retained under
`release-private/local-validation/2026-10-24/` (ignored by Git). Build/test logs,
status snapshots and the live stack/counter sample are under `/private/tmp/`;
native renders are in `build/native-previews/`. The original installed bundle
is also retained at `/private/tmp/lidpilot-rollback-20261024/LidPilot.app`.

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
