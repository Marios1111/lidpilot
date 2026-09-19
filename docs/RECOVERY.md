# Recovery and cleanup

Recovery is a normal product state, not a hidden best-effort detail. LidPilot
shows Recovery required whenever it cannot prove that its app-scoped
assertions, helper lease, or global sleep override have been released. It does
not mark cleanup successful because a command was attempted.

## States a user can see

| State | Meaning | Allowed next action |
| --- | --- | --- |
| Off | LidPilot has no active session and has verified its own controls are off. | Choose a mode and Start, or leave the Mac to macOS. |
| Starting | Preflight, cleanup, helper approval, or activation is in progress. | Wait, or press Turn Off; the newer generation wins. |
| Active | The requested mode, assertions, and helper lease have passed read-back. | Reconcile, switch mode with the same deadline, or Turn Off. |
| Paused | A safety or deadline condition ended the session. | Correct the condition and explicitly Start again. |
| Unverified | A helper status read failed without known owned state. | Refresh helper status in Settings; Keep Screen On remains independent. |
| Recovery required | Ownership or cleanup is uncertain, failed, or pending. | Keep the lid open, stop other controllers, and use explicit recovery. |
| Updating | Installation-capable update work holds the activation barrier. | Complete/cancel the update path; do not start a session. |

## Normal Turn Off and expiry

The coordinator advances its generation, marks the requested/effective mode
inactive, releases display and system assertions, releases the helper lease
when one exists, reads back the resulting state, and only then clears its
ownership hint and deadline. A timer ending follows this same release path. A
late activation reply is ignored because its generation is stale.

If assertion release, helper release, read-back, or journal cleanup fails, the
phase becomes Recovery required. The app keeps the recovery hint so a later
launch checks cleanup before allowing new activation.

## App disconnect or crash

The helper does not depend on a live UI countdown. Its maximum renewable lease
is 60 seconds, the intended app heartbeat is 15 seconds, and an independent
watchdog checks every 10 seconds. A disconnected client, expired deadline,
unknown safety observation, serious/critical thermal state, failed read, or
unexpected flag drift causes the helper to attempt restoration. The fixed
`pmset` child has a five-second execution limit and a bounded 0.25-second kill/reap window. If death cannot be confirmed, its inherited lock fences later recovery until the child exits. The live helper reopens the same validated lock inode on retry; it never explicitly unlocks an unverified child.

These values are bounded engineering targets, not a promise of exact physical
restoration timing. The helper retains recovery pending when restoration is
uncertain or fails, and retries from the watchdog path.

## Helper restart and journal recovery

Before accepting a new lease, the helper loads its fixed recovery record. The
record contains version, session UUID, generation, boot identity, and mutation phase; it never
contains a client path or command. The production journal is under
`/Library/Application Support/LidPilot`, with trusted root-owned ancestry,
restrictive permissions, no-follow opens, a 4 KiB bound, and atomic write/
`fsync`/rename behavior.

A verified-enable or explicitly authorized-restore record allows automatic restoration and independent read-back before clearing the record. A prepared/in-flight record is ambiguous if the flag is on or unknown, and requires explicit recovery; intent alone does not authorize clearing another controller. If the flag is off after acquiring the cross-process command fence, the incomplete record can be safely cleared. If the record is malformed, unsafe,
or cannot be restored, the helper reports recovery pending and blocks ordinary
acquisition. A corrupt journal is not permission to assume the flag is Off.

## Ambiguous ownership and external controllers

`SleepDisabled` is global and has no per-app ownership token. LidPilot refuses a
pre-existing active flag it cannot attribute to itself. It also stops or enters
recovery when an external writer changes the flag during a lease. It does not
silently write `0`, repeatedly fight the other utility, or claim that a read of
`1` proves panel power state.

The development host had `SleepDisabled=1` before ordinary testing. That read
was observation only and remains untouched. Developers should use mock drivers
for tests and should not “clean up” a pre-existing flag by hand.

## Explicit recovery action

When the app reports Recovery required:

1. Keep the lid open, save work, and stop any other closed-lid/sleep utility.
2. Confirm that no LidPilot session or update is active. Do not remove the app
   or helper bundle while ownership is unresolved.
3. Open Settings → Helper & Recovery and review the observed flag, helper
   status, message, and diagnostic preview.
4. Choose **Restore Normal Sleep Policy…** only after acknowledging that this
   action can change the system-wide sleep override. The app sends the explicit
   `recover` operation, then verifies the flag is Off and recovery pending is
   false.
5. If verification fails, leave the state visible and preserve Recovery
   required. Reconnect the signed helper or obtain maintainer assistance rather
   than issuing an arbitrary root command.

The explicit recover operation is not an automatic startup shortcut. It is
available only after the app has no active session and the user has confirmed
the ambiguous state. It does not restore another utility's setting or promise
that unrelated assertions have gone away.

## Stop & Sleep and updates

Stop & Sleep first completes the normal release/read-back path. It requests
macOS sleep only after assertions are Off and helper ownership is not pending.
If either check fails, it does not repeatedly request sleep and leaves the app
in Recovery required.

The update coordinator uses the same cleanup boundary. An installation-capable
manual check holds an update barrier, releases assertions and helper ownership,
requires an open lid, unregisters the helper, and preserves interrupted-update
state. Cancellation/no-update restores the helper only after the barrier is
safe; a committed update launches the new app Off. See
[`RELEASING.md`](RELEASING.md) for signed packaging gates.

## Uninstall and maintainer help

Use [`UNINSTALL.md`](UNINSTALL.md) only after cleanup is confirmed. Deleting the
bundle first can leave an unresolved global override. If the app cannot launch,
keep the Mac open and preserve the helper/journal state for a maintainer; do
not add a passwordless `sudo` rule or use an arbitrary root command.

Recovery tests cover delayed activation, generation invalidation, failed
restoration, helper restart, corrupt journal, replay/ownership rejection, and
update barriers. Real signed XPC, launchd, crash, and physical power recovery
remain G3-G5 validation work described in
[`HARDWARE_VALIDATION.md`](HARDWARE_VALIDATION.md).
