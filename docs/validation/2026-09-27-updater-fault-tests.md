# Actual coordinator fault regressions — September 27, 2026

The hostless `LidPilotAppTests` target compiles the real `UpdateCoordinator`
source and uses the real `SessionController` with in-memory power controls,
scripted helper/updater adapters, and unique temporary UserDefaults suites.
It does not launch the GUI, register a helper, modify power state, or exercise
Sparkle's live network and scheduler.

Seven tests pass via `./scripts/test-app.sh` (exit 0). The script is included in
CI; the test bundle is excluded from shipping app sources and uses its own
bundle identifier. Test-only entrypoints are compiled only with
`LIDPILOT_TESTING`; production feed, signing and identity guards remain intact.

Covered cases:

- Same-build pending-update state synchronously prevents session activation
  and remains held after relaunch until the user resolves the update.
- A newer build restores the helper and clears persisted update markers.
- Approval-required registration retains the helper repair hint.
- Injected helper-unregister failure prevents starting the Sparkle check and
  restores the prior helper state without a power mutation.
- Injected network failure restores the helper, clears update markers, and
  returns the controller Off.
- Committed/staged installation keeps its barrier across a same-build relaunch.
- Automatic and manual checks during an active display session are rejected
  without disturbing the in-memory session assertions.

## Reproduced duplicate cleanup

Before the new scheduling guard, two finish callbacks arriving before queued
cleanup ran both invoked `SessionController.endUpdate`, publishing Off twice.
The focused regression observed two Off events where one was expected and
exited 65. Helper registration itself already occurred only once because the
first cleanup cleared its restoration intent.

The fix admits one pending cycle cleanup. The same seven-test suite then passed
with one Off event and one helper registration. No watchdog, lease, mutation,
read-back, signing or recovery policy was relaxed.

Local logs: `/private/tmp/lidpilot-g5-duplicate-no-guard.log` (failing control),
`/private/tmp/lidpilot-g5-final.log` (passing restored guard). These are injected
coordinator fault results, not a claim that real network outages, staged Sparkle
process interruptions, or ServiceManagement failures were induced on the Mac.
Retained signed RC upgrade and RC10 uninstall evidence remain separate.
