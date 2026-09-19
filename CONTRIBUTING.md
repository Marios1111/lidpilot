# Contributing to LidPilot

LidPilot is a native Swift 6 macOS project. Contributions should keep the
policy core deterministic, keep the privileged helper narrow, and preserve the
distinction between a sampled setting and a claim about physical hardware.

The current development target is Apple Silicon with macOS 15 or later. The
source tree is authoritative for the generated Xcode project. Run the project
generator after adding or moving App or Helper sources:

```sh
gem install --user-install xcodeproj --version 1.27.0 --no-document
ruby scripts/generate-project.rb
ruby scripts/generate-project.rb --check
```

The normal verification entry points are:

```sh
./scripts/build.sh Debug
./scripts/build.sh Release
./scripts/test.sh
./scripts/verify.sh
./scripts/smoke-ui.sh
```

Local Debug and Release builds are intentionally ad hoc and do not make the privileged helper available. Distribution builds set `LIDPILOT_SIGNED_BUILD=1` and require a real `DEVELOPMENT_TEAM` and Developer ID identity; do not replace them with guessed or development values. The release
workflow is documented in [`docs/RELEASING.md`](docs/RELEASING.md).

## Boundaries to preserve

- Keep pure policy, deadline, snapshot, and wire types in `Core/`. Core must
  remain Foundation-only and must not import AppKit, IOKit, Security,
  ServiceManagement, or shell execution APIs.
- Keep the session coordinator as the owner of requested mode, effective
  behavior, observed state, deadlines, and generation invalidation. A UI,
  observer, or helper callback must not create a competing state machine.
- Keep Display mode app-scoped. It must not call the privileged helper or write
  the global `SleepDisabled` setting.
- Keep Smart and Closed helper requests typed and bounded. The helper accepts
  no arbitrary executable, shell string, path, environment, output destination,
  prompt, or workload transcript.
- Keep `/usr/bin/pmset` and its fixed arguments inside the helper driver. Do not
  add `sudo`, `osascript`, a password rule, or a general-purpose root endpoint.
- Keep `SleepDisabled` ownership explicit. A pre-existing active flag is an
  ownership conflict; do not clear it silently or fight external drift.
- Keep user-requested Stop and mandatory safety ahead of Start, renewal, and
  any future automation. A late callback must not revive a newer generation.
- Keep unknown and stale safety observations distinct from false values.
- Do not add analytics, cloud accounts, AI-agent detection, CLI control,
  remote control, Shortcuts, widgets, or process automation to V1.

## Safe test discipline

Default tests must use mocks and disposable journals. They must not register or
enable the helper, call a global power-setting write, or depend on a real
closed-lid machine. The development host was observed read-only with
`SleepDisabled=1`; preserve that pre-existing state and do not reset it for a
test.

The timing and recovery contracts have bounded starting targets: a 60-second
helper lease, a 15-second app heartbeat, a 10-second helper watchdog check, a
5-second fixed power-command timeout, and a bounded helper queue. These values
are testable engineering targets, not claims of real-time behavior. Changes to
them need failure-case tests and a documentation update.

Hardware experiments are opt-in and must follow
[`docs/HARDWARE_VALIDATION.md`](docs/HARDWARE_VALIDATION.md). Record the Mac
model, OS build, power source, display topology, lid state, test payload, and
observed evidence. Do not use fake input, brightness hacks, black overlays
presented as panel-off, blanket external-display blanking, or unlocking the
Mac to make a test appear successful.

## Making a change

1. Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and the relevant safety
   and recovery contract before changing a boundary.
2. Make the smallest change that satisfies the current V1 requirement. Avoid
   new dependencies and compatibility layers without a concrete requirement.
3. Add focused tests for a changed behavior or a realistic failure. Prefer a
   virtual clock, mock sampler, mock assertion controller, and mock helper.
4. Run the affected package tests, then `scripts/test.sh` and `scripts/verify.sh`
   when the project is available. Build both Debug and Release when build
   settings or packaging changed.
5. Inspect the complete diff, including generated project changes. Preserve
   unrelated user or worker changes, and do not commit secrets, credentials,
   private keys, or machine-specific power state.

Document whether evidence is local, committed, signed, deployed, or observed
on hardware. Passing unit tests does not establish physical panel behavior,
crash recovery on hardware, task continuity, signing, notarization, or a
complete update lifecycle.

## Review and security

Use clear, scoped commits. Explain the behavioral trigger, the safety impact,
and the checks that cover it. Security-sensitive changes to XPC authentication,
the helper, the journal, update replacement, or ownership recovery need a
focused review. See [`SECURITY.md`](SECURITY.md) for private reporting.

The project is currently unreleased. Do not publish artifacts, create a public
release, change production state, send external communications, or use signing
credentials as part of an ordinary contribution.
