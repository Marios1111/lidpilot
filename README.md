# LidPilot

LidPilot is a native macOS menu-bar utility for bounded keep-awake sessions. It
supports lectures and other open-lid work, plus carefully controlled local work
that should continue when a MacBook lid closes. It is written in Swift 6 for
Apple Silicon Macs running macOS 15 or later.

This checkout is an unreleased development snapshot. It has no public download
or repository URL configured, and it must not be described as a released,
notarized, or hardware-validated product. The concept artwork in `design/` is a
directional design artifact; it is not evidence of power behavior.

## Modes

The three modes are mutually exclusive. Selecting a preferred mode never starts
a session; launch and launch-at-login always leave LidPilot Off.

| User-facing mode | Internal mode | Behavior | Helper |
| --- | --- | --- | --- |
| Follow Lid | `smart` | Arm closed-lid support while open. Hold the system awake; hold the display only while the lid is open. | Required |
| Keep Screen On | `display` | Use app-scoped macOS assertions for the system and display while the session is active. | Not required |
| Keep Mac Running | `closed` | Hold the system awake while letting the display follow macOS policy. | Required |

Off releases LidPilot's own assertions and helper lease after read-back. It does
not clear another utility's sleep assertion or promise that the whole Mac is
already asleep.

Sessions can be 30 minutes, 1 hour, 2 hours, 4 hours, a custom duration, an
absolute “until” time, or indefinite until the user stops them. Finite sessions
use a monotonic clock and carry a hard deadline through the helper protocol.
Switching modes preserves the existing deadline. Turn Off, safety, and deadline
expiry invalidate older work so delayed activation cannot resurrect a session.

## Safety behavior

The policy engine fails closed when required observations are unknown, stale,
from another boot, or in the future. Serious or critical thermal pressure ends
every mode. On battery, the configurable floor is 10%, 20% (the default), or
30%; reaching the floor ends the session. Follow Lid and Keep Mac Running pause
on battery and Low Power Mode by default. Battery operation is an explicit
choice and never bypasses the floor. Safety pauses require an explicit restart;
LidPilot does not silently resume.

The app reports requested, effective, and observed state separately. A confirmed
`SleepDisabled` flag means that macOS accepted the sampled system setting. It is
not proof that the internal panel is physically off, that a workload completed,
or that a Mac is safe in a bag.

## Architecture

The pure policy and wire types live in [`Core/`](Core/). The app-side session
coordinator and native integrations live in [`Runtime/`](Runtime/) and
[`App/`](App/). Closed-lid support is a narrow, authenticated XPC path to the
privileged helper in [`Helper/`](Helper/). Read the detailed contracts in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), [`docs/SAFETY.md`](docs/SAFETY.md),
and [`docs/RECOVERY.md`](docs/RECOVERY.md).

The helper exposes typed inspect/acquire/renew/release/recover operations. It
accepts no executable, shell string, client path, or arbitrary output request.
The production driver has one fixed executable and fixed arguments:
`/usr/bin/pmset -a disablesleep 1` and `0`. The helper journal is root-owned,
permission checked, and written atomically before a mutation.

## Development and safe testing

Normal tests use mock clocks, samplers, assertions, helper transport, power
drivers, and journals. They do not install or enable the helper and must not
change this Mac's global power policy. During development, a read-only
`pmset -g` inspection reported `SleepDisabled=1` on the host; that pre-existing
state is preserved and is not treated as LidPilot ownership. The user confirmed
another closed-lid controller is actively managing it. Do not run a write to
reset it as part of ordinary tests.

The supported project wrappers are:

```sh
./scripts/build.sh Debug
./scripts/build.sh Release
./scripts/test.sh
./scripts/verify.sh
./scripts/smoke-ui.sh
```

For isolated native UI testing, run the Debug executable with `LIDPILOT_UI_TESTING=1`. This uses in-memory power/helper implementations, separate preferences, a visible preview badge, and a preview window. It cannot install the helper or change power policy; the harness is absent from Release builds. `scripts/smoke-ui.sh` uses that harness to render the native views and verify mock activation, cleanup, and normal app exit. Native menus, forms, keyboard navigation, and VoiceOver still require an unlocked interactive session.

The wrappers run local build, test, and verification steps; a successful local
run is not a signing, notarization, hardware, or publication result. The
project check is:

```sh
ruby scripts/generate-project.rb --check
```

The package-level Core tests can be run from `Core/` with SwiftPM. If Xcode's
sandbox blocks its compiler module cache, use a disposable scratch directory
and a local module-cache path; never work around that by installing the helper
or changing power settings.

## Known validation gates

The logic and mock tests are useful evidence, but they do not replace the
following gates:

- G1: measure the native display assertion and determine whether the desired
  inactivity dimming-without-display-off behavior is actually available. The
  current implementation uses `preventUserIdleDisplaySleep`, which suppresses
  normal idle dimming/display sleep while held; it does not provide a separate
  native dimming control.
- G2: observe physical built-in panel/backlight behavior across open, closed,
  docked, external-display, and virtual-display topologies. The current code
  does not measure panel power.
- G3: exercise real app/helper crashes, reconnects, delayed replies, command
  timeouts, read-back failures, and recovery on Apple Silicon hardware.
- G4: validate signed peer authentication and the launchd/ServiceManagement
  lifecycle with real publisher-signed identities.
- G5: validate signed/notarized packaging, Sparkle replacement, helper upgrade,
  and uninstall with real release credentials.

The complete opt-in checklist is in
[`docs/HARDWARE_VALIDATION.md`](docs/HARDWARE_VALIDATION.md), with the current
support boundary in [`docs/SUPPORT_MATRIX.md`](docs/SUPPORT_MATRIX.md).

## Privacy and scope

LidPilot has no account, cloud service, analytics SDK, AI agent detection, CLI,
remote control, Shortcuts integration, or workload transcript access in V1.
Diagnostics are local, bounded, and redacted before export. The app observes
only the power, lid, thermal, Low Power Mode, display-topology, assertion, and
helper state needed for its stated behavior.

Release, update-feed, signing, and publication constraints are documented in
[`docs/RELEASING.md`](docs/RELEASING.md). The safe removal path is in
[`docs/UNINSTALL.md`](docs/UNINSTALL.md). Contributions should follow
[`CONTRIBUTING.md`](CONTRIBUTING.md), and security reports should follow
[`SECURITY.md`](SECURITY.md).

LidPilot is distributed under the [MIT License](LICENSE).
