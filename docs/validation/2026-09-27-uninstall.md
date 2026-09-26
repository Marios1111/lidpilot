# RC10 uninstall and restoration — September 27, 2026

Signed uninstrumented production build 10 (`d74d767`) was Off with independent
SleepDisabled=0 before removal. Original defaults: Keep Mac Running / 30 minutes,
notifications Off, launch at login On.

Through native Settings, launch at login was disabled, then Remove Helper was
confirmed. Native status became Not installed / Off / override off. Normal Cmd-Q
was performed. launchd reported `com.lidpilot.app.helper` absent (exit 113); the
development helper had already been removed. No installed app process remained.
The stopped bundle was moved reversibly from `/Applications/LidPilot.app` to
`/private/tmp/LidPilot-RC10-uninstall-rollback-20260927.app`. Applications absence
was confirmed. Native System Settings Open at Login no longer listed LidPilot.
Independent SleepDisabled=0 and ordinary power-profile values remained unchanged.
Background Items retained historical “Last ran” rows; these are not running
services, and no BTM history reset was performed. Preferences and diagnostics
were preserved; unrelated settings were not deleted.

The exact same bundle was moved back to Applications, with deep/strict signature
verification passing. Relaunch was Off. Its helper registered normally without
new authentication, became Approved, and Refresh read the override off. Original
launch-at-login On and notifications Off were confirmed in native Settings.
Only the usual production app was restored; the development instance stayed quit.

**PASS:** orderly login-item cleanup, helper unregister, app quit/removal from
Applications, no remaining LidPilot helper service, unmodified SleepDisabled,
and same-signed-bundle recovery. This used reversible relocation rather than
Trash deletion; it does not test deleting user preferences or BTM historical rows.
A final stable-build uninstall regression remains part of final artifact validation.
