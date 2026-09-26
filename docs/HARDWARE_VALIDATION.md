# Hardware validation checklist

This checklist is an opt-in test plan, not evidence that the current checkout
has passed it. Logic tests and mock helpers can establish ordering, bounds, and
failure handling; only a deliberate Apple Silicon test can establish native
display, lid, launchd, signed-identity, and update behavior.

Do not run the intrusive steps below during ordinary development. They may
change the Mac's global sleep policy, install a privileged helper, close a lid,
or exercise a real update. A maintainer must explicitly authorize the selected
step and record the evidence before marking a gate passed.

## Test record and preflight

Record these facts for every run:

| Field | Record |
| --- | --- |
| LidPilot commit, marketing version, build |  |
| Mac model/chip and memory |  |
| macOS version/build |  |
| Power source and battery percentage |  |
| Displays: built-in, direct external, dock, virtual, count |  |
| Lid state and login/lock state |  |
| Helper signing team and approval state |  |
| Test operator and explicit authorization |  |
| Test payload and start/end timestamps |  |
| Logs, photos, observations, and pass/fail reason |  |

Before a real-machine run:

- Use a ventilated desk, a recoverable test account, and a harmless timestamp-
  writing task. Do not use secrets, an irreplaceable build, a production task,
  or a Mac that must remain available.
- Keep the lid open for setup and recovery. Save work and keep the documented
  recovery path visible.
- Capture a read-only baseline of lid, power, thermal, display topology, and
  the system sleep flag. If the
  flag is already active and unowned, stop the test. Do not write `0` merely to
  make a baseline look clean. Ask the other controller to stop normally, then
  independently verify the flag is `0` before LidPilot takes ownership. See
  [the dated prerequisite record](validation/2026-09-21-prerequisites.md) for
  the development host's initial state and its eventual clean read-back.
- Confirm that no other sleep controller is active. Do not run two controllers
  and call the resulting flag a LidPilot result.
- Use mock Core/Runtime tests for ordinary CI. Do not install/enable the helper
  or issue global power writes as part of `scripts/test.sh` or a Debug build.
- Keep evidence separate for sampled flags, assertion properties, observed
  display/backlight behavior, workload continuity, and recovery timing.

The current native code deliberately avoids fake input, private brightness
writes, black overlays presented as panel-off, blanket external-display
blanking, and unlocking the Mac. A test that needs one of those shortcuts is a
failed test design, not a passed gate.

## G1 - native inactivity dimming and display sleep

**Question:** Can a supported public macOS mechanism allow normal inactivity
dimming while preventing idle display-off for the intended mode?

Current implementation fact: Display and open-lid Smart use
`kIOPMAssertionTypePreventUserIdleDisplaySleep`. Holding this native assertion
suppresses normal idle display sleep/dimming while held. The code does not
provide a separate native dimming control and does not claim that a dimmed
frame, a brightness value, or a black window is panel power evidence.

Opt-in procedure:

1. On the selected minimum and latest supported macOS builds, record manual
   brightness, automatic brightness, True Tone/Night Shift, and existing
   display-sleep preferences without changing them.
2. Run an Off baseline long enough to observe native inactivity dimming and
   idle display-off separately.
3. Run a bounded Display session with no helper. Confirm through local
   diagnostics that only LidPilot's app-scoped assertions are held.
4. Repeat the inactivity interval and record whether the panel dims, remains
   lit at the same level, and eventually powers down. Repeat on battery and
   external power, with the built-in panel and with an external display.
5. Stop the session and confirm both assertions release and macOS preferences
   remain unchanged.

Record two separate results: whether native dim-without-off is available, and
whether the supported keep-screen-on behavior passes. The release-validation
scope permits a measured limitation when a safe public mechanism cannot
provide independent dimming. In that case acceptance requires working manual
brightness, a recorded automatic-brightness observation, prevention of idle
display-off, verified assertion cleanup, and clear product documentation of
suppressed idle dimming. Do not mark dim-without-off as implemented or infer a
hardware pass from the assertion alone. An unavailable topology/OS remains
untested rather than inheriting another setup's result.

## G2 - physical internal-panel behavior

**Question:** What happens to the actual built-in panel/backlight when the lid
closes, especially with external or virtual displays present?

An active sleep flag, display assertion, brightness value, registry property,
or screenshot is not enough. The test must use a physical observation method
and record the hardware/topology, because a closed Mac can keep a backlight lit
even when the sampled flag is on.

Opt-in matrix:

| Case | Built-in only | Direct external | Dock | Virtual/multiple |
| --- | --- | --- | --- | --- |
| Open, Off | Record evidence | Record evidence | Record evidence | Record evidence |
| Open, Display | Record evidence | Record evidence | Record evidence | Record evidence |
| Smart, open then close | Record evidence | Record evidence | Record evidence | Record evidence |
| Closed, open then close | Record evidence | Record evidence | Record evidence | Record evidence |
| Reopen and reconcile | Record evidence | Record evidence | Record evidence | Record evidence |

For each case, record lid transition timing, assertion state, sampled
`SleepDisabled`, external-display behavior, built-in panel/backlight state,
workload continuity, and recovery after reopening. Do not use a blanket
display-sleep command that could blank an external or virtual display. The
current app intentionally reports **Internal panel power: Not measured**.
The dated validation records retain built-in-display continuity, delayed
darkness, and reopening observations. Those observations do not pass the
unavailable external/dock/virtual cases. The owner approved built-in-only V1
display support on September 25; broader topologies are deferred evidence.

## G3 - real app/helper failure and recovery

**Question:** Does the real signed app/helper lifecycle restore LidPilot-owned
state after failure without extending a hard deadline or hiding uncertainty?

Run only after G4 identity prerequisites are satisfied and with an explicitly
authorized test session. Use a disposable journal/test account and a harmless
payload. Exercise:

- app termination during Starting, Active, close/reopen, and Stop;
- helper termination and launchd restart during a lease;
- delayed XPC replies and an expired finite deadline;
- a five-second command timeout with child kill/reap;
- failed enable, failed read-back, failed restore, and retry;
- corrupt, loose-permission, missing, and symlinked journal records;
- charger, thermal, lid, topology, and external-flag changes during a lease;
- duplicate, replayed, wrong-client, oversized, malformed, and stale-generation
  requests;
- explicit recovery followed by a verified Off read-back;
- Stop & Sleep only after assertions and helper ownership are confirmed Off.

Record the time from failure to the first recovery attempt and the final
verified state. The 60-second lease, 15-second heartbeat, 10-second watchdog,
and five-second command timeout are target bounds, not exact guarantees. Core
and Runtime fault tests are logic evidence; they do not pass G3 on their own.

## G4 - signed peer authentication and privileged boundary

**Question:** Can only the intended signed application reach the intended
privileged helper, and does the helper keep its narrow command surface?

Prerequisites are a real development/release signing identity, a generated
arm64 app/helper bundle, and an approved ServiceManagement registration. Verify:

- app and helper bundle identifiers are `com.lidpilot.app` and
  `com.lidpilot.app.helper`;
- both sides require the expected Apple signing anchor and exact team;
- a wrong identifier, unsigned client, stale helper, wrong console user, and
  second client are rejected; retain genuine different-team testing when a
  separate valid signing team is available (owner-reviewed deferred independent
  evidence for V1, never a fabricated same-team substitute);
- the helper admits only bounded typed operations and rejects wrong protocol,
  zero generation, missing/inconsistent payloads, display acquire, malformed
  data, and payloads over 16 KiB;
- no request can select an executable, path, shell, environment, `sudo`, or
  arbitrary output destination;
- journal ancestry/ownership/permissions and no-follow behavior hold on the
  real installation;
- a failed or interrupted mutation leaves recovery pending rather than
  reporting success.

Do not weaken signing requirements for this gate. Mock `HelperIdentity` and
wire tests establish rejection logic but do not establish real code-signing or
launchd identity. Real signed XPC and rejection evidence is already retained in the dated
records; new identity-isolation and final-candidate lifecycle checks must be
recorded separately.

## Performance and accessibility acceptance

On each release candidate, record a settled ten-minute active session with the
popover closed and the workload excluded from measurements. The owner revised V1 acceptance on September 26 to average inclusive CPU
at or below 1.0% of one core over 600 seconds (app, helper and children),
combined app/helper physical footprint at or below 75 MiB, and visible UI
feedback within 100 ms, without sustained busy-loop/runaway behavior or
weakened safety semantics. The original 0.2% goal is deferred to post-V1
optimization. Measure pending feedback separately from completion of
a system change. Verify no per-second rendering while the popover is hidden.

Also inspect keyboard navigation, VoiceOver, light/dark appearance, Increase
Contrast, Reduce Transparency, and Reduce Motion. Confirm the finite/custom/
until-time controls and the reason/next action for every error state. A rendered
SwiftUI image cannot verify native menus, VoiceOver, or these timing budgets.
Aim for the final compressed DMG below 25 MiB; record its actual size after
signing and stapling. These measurements are still open release gates.

## G5 - signed update, helper replacement, and uninstall

**Question:** Can a real published artifact be installed, upgraded, and removed
without silently interrupting a session or leaving a privileged override?

Use a disposable prior build and real publisher credentials kept outside the
repository. Verify the full sequence:

1. Build arm64 Debug and Release artifacts with the expected version/build.
2. Sign the app and its embedded helper. Submit the app as a ZIP for
   notarization, then staple the app. Create, sign, notarize, and staple the
   final DMG. Create the separate Sparkle archive from the stapled app;
   archives receive Ed25519 signatures, not staple tickets.
3. Validate Sparkle 2.10.0 signed archive, feed, and release-note metadata,
   including immutable version-specific download bytes and failure-expiration
   behavior.
4. Discover an update while Off. While any session is active, confirm that
   manual and scheduled checks are deferred without presenting a modal alert
   or interrupting assertion renewal. Installation requires the barrier to
   prove Off, assertions released, lid open, helper quiesced, and ownership
   read back.
5. Start a manual check while Off, cancel it, receive no update, fail cleanup,
   lose network, close the lid, and interrupt the app. Confirm barrier
   persistence, safe helper restoration, and no automatic session restart.
6. Install a valid update, verify the replacement helper identity/protocol/build,
   and verify that the updated app starts Off with preferences preserved.
7. Run the documented uninstall path only after verified cleanup and helper
   unregistration. Confirm that unrelated macOS settings and other utilities'
   assertions remain unchanged.

G5 is blocked without Developer ID, notarization, Sparkle private/public key
handling, a real feed/archive, and a previous signed build. Local metadata
self-tests and project checks are not G5 evidence.

## Gate record

Mark a gate only with a retained record containing the exact build, hardware,
OS, setup, steps, raw observations, screenshots/photos where appropriate,
failure details, cleanup result, and reviewer. Use these statuses:

| Status | Meaning |
| --- | --- |
| Logic evidence | Mock or pure tests passed; no hardware/release claim. |
| Ready for opt-in | Preconditions and a bounded procedure exist. |
| Passed on recorded setup | The exact setup passed; this does not generalize to every Mac. |
| Blocked | Required credentials, hardware, or a safe observation method is missing. |
| Failed | The recorded setup contradicted the required behavior or cleanup. |

Public release remains blocked until all mandatory G1-G5 evidence is reviewed.
See [`SUPPORT_MATRIX.md`](SUPPORT_MATRIX.md) for the support claims that may be
made before then.
