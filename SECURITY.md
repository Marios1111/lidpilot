# Security policy

LidPilot controls a system-wide macOS sleep-prevention flag through a small
privileged helper. The helper is a security boundary and is deliberately less
capable than a general root command runner. Treat any path that could make an
unowned helper mutate power policy, bypass peer authentication, or conceal
failed restoration as high priority.

This checkout is an unreleased development snapshot. It has no public security
contact URL or release feed configured. Do not invent one, and do not disclose
an unverified issue in a public issue tracker. Use the private reporting route
provided by the maintainer or the repository host once that route is supplied.

## Boundary and invariants

- The menu-bar app owns user intent, deadlines, generation changes, status, and
  app-scoped IOPM assertions. It does not write the global closed-lid flag.
- The XPC service accepts bounded, typed `WireRequest` values only: inspect,
  acquire, renew, release, and explicit recover. Payloads are capped at 16 KiB
  and include a protocol version, session UUID, nonzero generation, and a
  validated deadline/policy where required.
- The helper authenticates the application with a code-signing requirement
  containing the expected application identifier and ten-character signing
  team. It also checks the current console user and bounds active clients and
  queued requests.
- The production power driver invokes only `/usr/bin/pmset` with fixed
  `-g` or `-a disablesleep 1/0` arguments. It accepts no executable, arguments,
  shell string, environment, path, or output destination from XPC.
- Commands have a five-second runtime limit plus a bounded 0.25-second kill/reap window. An unverified child retains an inherited file lock; later recovery must acquire that lock before proceeding. The XPC reply path has a 30-second timeout. The helper watchdog is scheduled
  independently every ten seconds and the intended lease/heartbeat targets are
  60/15 seconds.
- The recovery journal is kept at the helper's fixed path under
  `/Library/Application Support/LidPilot`, with trusted root-owned ancestry,
  restrictive directory/file permissions, no-follow opens, bounded size, and
  atomic write/fsync/rename. The protocol never accepts a journal path.
- The helper refuses a pre-existing active `SleepDisabled` flag that it cannot
  prove it owns. Failed restoration remains recovery pending. An explicit user
  recovery action is required for ambiguous state.

These invariants do not make `SleepDisabled` reference-counted or observable as
physical panel power. Another utility can change the same global setting, a
failed helper can outlive the app, and macOS hardware can keep a panel lit even
when a sampled flag is on. Those cases stay visible as conflicts or validation
gates.

## Privacy boundary

Core modes do not require an account, cloud service, Accessibility, Screen
Recording, microphone, camera, Contacts, or Full Disk Access permission. Local
diagnostics retain a bounded seven-day event window and redact path-like text
before storage/export. They do not intentionally store names, contact data,
prompts, transcripts, workload files, or health information. LidPilot has no
analytics SDK or AI-agent detector.

## Reporting a vulnerability

For a private report, include the app/build identifier, macOS version and
hardware model, the smallest reproducible sequence, expected and observed
ownership/recovery state, and a redacted diagnostic preview. Remove usernames,
paths, signing material, recovery-journal contents, personal data, and secrets
unless the maintainer explicitly requests a protected copy.

Do not test a suspected issue by writing this Mac's global power setting,
installing an unsigned helper, weakening code-signing requirements, changing
launchd registration, or running an irreplaceable workload. Use a disposable
mock or an explicitly approved hardware test following
[`docs/HARDWARE_VALIDATION.md`](docs/HARDWARE_VALIDATION.md).

Maintainers should acknowledge receipt privately, reproduce in a disposable
environment, identify whether the issue is source-reproduced or hardware-only,
and coordinate a release only after the relevant signing, recovery, and
hardware gates pass. No severity or response-time promise is made for this
unreleased snapshot.
