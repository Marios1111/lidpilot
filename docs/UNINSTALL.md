# Uninstalling LidPilot

LidPilot must remove its own managed state before its files are deleted. The
normal path is intentionally initiated from the app so the coordinator can
stop a session, release app-scoped assertions, release the owned helper lease,
read the resulting state back, and record recovery if cleanup is uncertain.

1. Open LidPilot with the lid open.
2. Choose **Turn Off** and wait for the app to show confirmed cleanup. If it
   reports **Recovery required**, follow that repair path before uninstalling.
3. Open **Settings → General** and turn off **Launch at login**. Then open
   **Helper & Recovery** and choose **Remove Helper…**. Confirm the action.
4. Allow the app to remove its ServiceManagement registration through the
   supported API. Do not delete the daemon bundle while a session or cleanup
   operation is pending.
5. Confirm that the app reports the helper as removed, quit LidPilot normally,
   then move the app to the Trash.

If the app cannot launch, keep the Mac open and avoid deleting the bundle
until a maintainer has reviewed the recovery journal and the observed sleep
state. Removing files first can leave an unresolved global sleep override.
Follow the [recovery procedure](RECOVERY.md). Recovery never requires a
passwordless sudo rule or an arbitrary root command.

Uninstalling the app does not change unrelated macOS power preferences or
other software's sleep assertions. A user-requested system sleep remains a
separate macOS action.
