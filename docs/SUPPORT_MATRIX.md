# Support matrix

LidPilot is in public release-candidate validation. This matrix states the
intended V1 boundary and the evidence currently available for each area. A
target platform is not a claim that its physical behavior, signing, recovery,
or update lifecycle has passed validation.

## Declared target

| Area | V1 boundary | Current evidence/status |
| --- | --- | --- |
| Hardware | Apple Silicon Mac with a built-in lid, plus supported external-display topologies | M4 MacBook Air/built-in panel has G1 and bounded G2 evidence; other models/topologies are untested |
| Operating system | macOS 15 or later | Source and project settings target macOS 15; each release must record the tested OS build |
| Architecture | Native Swift 6, SwiftUI/AppKit, menu-bar app, arm64 | Debug/Release and CI passed; signed/notarized RC1 and its actual helper ran on the recorded host |
| Modes | Follow Lid, Keep Screen On, Keep Mac Running, and Off | Keep Screen On/Off observed; Follow Lid and Keep Mac Running continuity/reopen observed on the built-in display |
| Sessions | Finite duration, absolute end time, indefinite session, explicit Stop | Core and Runtime logic evidence; delayed replies must not extend the hard deadline |
| Safety | Thermal, battery floor, Low Power Mode, lid, topology, freshness, boot, and helper availability checks | Core and Runtime logic evidence; live sensor and physical behavior require opt-in validation |
| Display control | App-scoped public macOS assertions | Built-in G1 manual/ambient brightness and no-idle-off observed; independent idle dimming is not provided |
| Internal panel | Physical built-in panel/backlight behavior | Operator observed dark screen after about one minute closed under the current idle policy; immediate or universal shutdown is not claimed |
| Closed-lid control | Authenticated helper lease around fixed `pmset` operations | Real ServiceManagement approval, signed helper and publisher/wrong-ID/ad-hoc/wrong-console enforcement passed on RC1; remaining G4 cases open |
| Recovery | Durable journal, read-back, ownership ambiguity, explicit recovery | Real GUI crash restored the owned override in 0.28 s; lease expiry restored it by the 65-second sample, but RC1's GUI falsely reported Recovery required afterward. Corrected-source retest and other G3/G4 cases remain open |
| Updates | Sparkle 2 signed update path with an activation barrier | RC1 app/DMG notarized and stapled; signed public archive/feed verified; real upgrade/replacement/uninstall pending |
| Removal | Open-lid cleanup, verified helper unregistration, then app removal | Documented path; real installation cleanup is part of G5 |
| Accessibility | Native SwiftUI/AppKit controls and labels | Keyboard flows, user-assisted VoiceOver speech, Light/Dark and contrast/transparency/motion settings checked; preferred-reading-size scaling is not claimed |
| Diagnostics | Local, bounded, redacted diagnostics | Seven retention, redaction, storage, and malformed-input tests pass; native preview and local Save dialog export passed |
| Privacy | No account, cloud service, analytics, AI-agent detection, CLI, or remote-control feature | V1 scope and source review; reassess every new dependency |

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
not a full hardware matrix or stable release approval. See
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
| Displays | Built-in only; direct external; dock; virtual display; multiple displays |
| Thermal | Nominal; fair; serious/critical transition; unknown/stale thermal observation |
| Session | Finite continuous deadline; absolute wall-clock end; indefinite; Stop during a delayed operation |
| Ownership | Off baseline; LidPilot-owned state; pre-existing unowned override; ambiguous read-back |
| Failure | App stop; helper stop; delayed reply; command timeout; failed enable; failed restore; corrupt journal |
| Update | Active discovery; manual Off check; cancellation/no update; interrupted update; successful signed replacement |
| Removal | Normal cleanup; helper unregistration; recovery-required refusal; final app removal |

For the real-machine procedure, use the preflight and retained-record rules in
[`HARDWARE_VALIDATION.md`](HARDWARE_VALIDATION.md). Do not change the host's
pre-existing global power state just to make a matrix cell pass; the
initial `SleepDisabled=1` observation belonged to another controller. In the
September 21 authorized preflight, that controller was asked to quit normally;
independent read-back subsequently confirmed `0`. LidPilot did not clear it.
