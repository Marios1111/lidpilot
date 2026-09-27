# Support matrix

LidPilot 1.0.0 is published. This matrix states the
V1 support boundary and retained evidence for each area. A
target platform is not a claim that its physical behavior, signing, recovery,
or update lifecycle has passed validation.

## Declared target

| Area | V1 boundary | Current evidence/status |
| --- | --- | --- |
| Hardware | Apple Silicon Mac with a built-in lid; V1 display support limited to the tested built-in-only setup | M4 MacBook Air/built-in panel has G1 and bounded G2 evidence; other models/topologies are untested |
| Operating system | macOS 15 or later | CI builds and tests on macOS 15; installed hardware tests ran on the recorded macOS 27.2 beta host, not a macOS 15 machine |
| Architecture | Native Swift 6, SwiftUI/AppKit, menu-bar app, arm64 | Debug/Release and macOS 15 CI passed; stable build 12 is Developer ID signed, notarized, stapled and installed through Sparkle with its build-12 helper |
| Modes | Follow Lid, Keep Screen On, Keep Mac Running, and Off | Keep Screen On/Off observed; Follow Lid and Keep Mac Running continuity/reopen observed on the built-in display |
| Sessions | Finite duration, absolute end time, indefinite session, explicit Stop | Core and Runtime logic evidence; delayed replies must not extend the hard deadline |
| Safety | Thermal, battery floor, Low Power Mode, lid, topology, freshness, boot, and helper availability checks | Core and Runtime logic evidence; live sensor and physical behavior require opt-in validation |
| Display control | App-scoped public macOS assertions | Built-in G1 manual/ambient brightness and no-idle-off observed; independent idle dimming is not provided |
| Internal panel | Physical built-in panel/backlight behavior | Operator observed dark screen after about one minute closed under the current idle policy; immediate or universal shutdown is not claimed |
| Closed-lid control | Authenticated helper lease around fixed `pmset` operations | Real ServiceManagement approval, signed helper and publisher/wrong-ID/ad-hoc/wrong-console enforcement passed; RC2–RC4 replacement helpers acquired the override. Genuine different-team client remains untested, explicitly deferred by owner review; exact Team ID and bundle signing requirement remains mandatory |
| Recovery | Durable journal, read-back, ownership ambiguity, explicit recovery | Real RC1 and RC3 GUI crashes restored the override; RC2 lease expiry and helper crash/restart restored it with no false Recovery. RC3 finite deadline ended Off. RC11 GUI crash restored Off by the first 1.040348-second sample and relaunched to native Off with no false Recovery; fault boundaries remain explicitly classified in the fault-evidence matrix |
| Updates | Sparkle 2 signed update path with an activation barrier | Real signed RC1→RC2→RC3→RC4 upgrades, Off relaunch, replacement helpers and canceled-check cleanup passed. RC11 signed no-update cycle restored its helper and cleared markers; ten actual-coordinator tests cover injected interruption/failure paths. RC10 uninstall passed; RC11→stable build 12 installed and relaunched with override/assertions Off; final stable native cleanup/Homebrew installation is pending |
| Performance | ≤1.0% mean inclusive CPU of one core over 600 s, ≤75 MiB combined physical footprint, no sustained busy-loop/runaway | RC10 600-second inclusive capture PASS: 0.799277% CPU, 72.262662 MiB mean / 72.392181 MiB maximum, recorded wakeups and no sustained runaway. macOS 27.2 beta 26B5091g. Exact click-to-visible timing is unmeasured and accepted by the owner as a post-V1 optimization goal; native response/render evidence is retained |
| Removal | Open-lid cleanup, verified helper unregistration, then app removal | RC10 native login/helper cleanup, app removal from Applications and same-bundle restoration passed; final stable native cleanup/Homebrew regression is pending |
| Accessibility | Native SwiftUI/AppKit controls and labels | Keyboard flows, user-assisted VoiceOver speech, Light/Dark and contrast/transparency/motion settings checked; preferred-reading-size scaling is not claimed |
| Diagnostics | Local, bounded, redacted diagnostics | Seven retention, redaction, storage, and malformed-input tests pass; native preview/local export and RC11 Copy Status paste passed |
| Privacy | No account, cloud service, analytics, AI-agent detection, CLI, or remote-control feature | V1 scope and source review; reassess every new dependency |

The [September 25 owner decisions](validation/2026-09-25-audit-closeout.md) narrow
display support and defer genuine different-team evidence. Unavailable hardware
is not a failed implementation and is not a test pass. On September 26 the owner
accepted the current Mac as the V1 validation host: passing installed tests on
its recorded beta OS may satisfy the corresponding V1 gates; a separate
stable-OS installation is not required. This does not relabel the beta OS as a
stable release or establish physical coverage on every supported OS. The
owner revised V1 inclusive CPU acceptance to ≤1.0% on September 26. The
≤0.2% budget remains a post-V1 goal. RC10 CPU/memory acceptance passed;
final source CI and signed artifacts passed; exact click latency is an accepted unmeasured post-V1 goal. See the current verification ledger for final native removal status.

## Mode and helper boundary

| User action | Helper | Intended behavior | Main gate |
| --- | --- | --- | --- |
| Follow Lid | Required | Arm while open, keep the system awake, and release the display assertion when the lid closes | G2/G3/G4 |
| Keep Screen On | Not required | Hold app-scoped system/display assertions for the active session | G1/G2 |
| Keep Mac Running | Required | Keep the system awake while the display follows normal macOS policy | G2/G3/G4 |
| Off | Released | Release LidPilot-owned controls and verify the resulting observed state | G3/G4 |

Unknown observations fail closed. Battery and Low Power Mode decisions depend
on the selected safety policy; no mode silently resumes after a safety pause.
Launch and launch-at-login start Off, and a preferred mode or duration does
not activate a session.

## Validation evidence levels

Use the following evidence labels when reporting support:

| Label | Meaning |
| --- | --- |
| Logic evidence | Pure/Core or mock Runtime tests cover the rule or failure path. |
| App evidence | The generated native app was exercised on the recorded machine without claiming physical power behavior. |
| Hardware evidence | The exact Mac, OS, topology, and procedure produced a retained G1-G3 result. |
| Release evidence | Signed, notarized, update, helper replacement, and removal checks produced a retained G4-G5 result. |
| Open gate | The required observation, credential, or physical procedure has not passed. |

The current snapshot has logic evidence for core deadlines, safety policy,
wire validation, helper leases, recovery journal handling, session races, and
mode transitions. It also has the bounded hardware and release evidence in
[the September 21 record](validation/2026-09-21-native-and-release.md) and
[the September 23 follow-up](validation/2026-09-23-closed-lid-and-lease.md). This is
not a full hardware matrix. See
[`HARDWARE_VALIDATION.md`](HARDWARE_VALIDATION.md) for the opt-in G1-G5
procedures and [`SAFETY.md`](SAFETY.md) for the fail-closed rules.

## Test coverage grid for a release candidate

This grid describes the combinations that must be recorded; it is not an
empty pass/fail claim. A maintainer should attach the evidence identifier for
each exercised combination.

| Dimension | Required cases |
| --- | --- |
| Power | External power; battery above floor; battery at floor; Low Power Mode on and off |
| Lid | Open; close while active; reopen; unknown/stale lid observation |
| Displays | V1: built-in only. Deferred/unvalidated: direct external, dock, virtual and multiple displays |
| Thermal | Nominal; fair; serious/critical transition; unknown/stale thermal observation |
| Session | Finite continuous deadline; absolute wall-clock end; indefinite; Stop during a delayed operation |
| Ownership | Off baseline; LidPilot-owned state; pre-existing unowned override; ambiguous read-back |
| Failure | App stop; helper stop; delayed reply; command timeout; failed enable; failed restore; corrupt journal |
| Update | Active check refusal without a modal; manual Off check; cancellation/no update; interrupted update; successful signed replacement |
| Removal | Normal cleanup; helper unregistration; recovery-required refusal; final app removal |

For the real-machine procedure, use the preflight and retained-record rules in
[`HARDWARE_VALIDATION.md`](HARDWARE_VALIDATION.md). Do not change the host's
pre-existing global power state just to make a matrix cell pass; the
initial `SleepDisabled=1` observation belonged to another controller. In the
September 21 authorized preflight, that controller was asked to quit normally;
independent read-back subsequently confirmed `0`. LidPilot did not clear it.
