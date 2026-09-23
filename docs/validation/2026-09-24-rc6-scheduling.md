# RC6 scheduling candidate — installed validation pending

Source `5a44e31a0e7a90cf3fb20476c265fff05522cec3`, version 1.0.0/build 6.
Local diagnostic build with `LIDPILOT_PROFILE_BUILD=1`; not published.

The sole runtime change is launchd ProcessType Background → Standard.
Utility queues, watchdog/heartbeat cadence, all independent reads, mutation
fencing, identity checks, leases and recovery remain unchanged. The bounded
comparison and rationale are in [the RC5 record](2026-09-24-rc5-profile.md).
CPU-time reduction alone does not establish improved energy efficiency.

- 58 Runtime and 21 Core tests passed.
- Debug and Release builds passed. Initial sandboxed build could not write
  Xcode's manifest cache; the authorized cache-access retry passed.
- Static project, plist and release fixtures passed; release dry-run passed.
- Diagnostic signed archive/export succeeded. Strict deep signature passed;
  embedded launchd plist reports Standard.
- Apple notarization `10d513cb-0560-48cc-abaa-f5099ccd6a02`: Accepted.
  Stapling and staple validation passed.
- Local bundle:
  `/private/tmp/lidpilot-release-501-rc6-profile/1.0.0-rc.6-6-profile/export/LidPilot.app`.
- [Source CI](https://github.com/Marios1111/lidpilot/actions/runs/35934022684)
  was running at this checkpoint.

Installed RC5 remains Off, with independent SleepDisabled=0 and no LidPilot
wake assertions after the last comparison. The temporary diagnostic LaunchAgents
were removed. RC6 has not yet replaced the installed app/helper. Next: remove
RC5's helper through native Settings, retain the old app, install RC6, verify
Off/registration, then run the same installed 600-second process-tree capture.
Energy/response comparison and a final uninstrumented run remain mandatory.
Performance is not passed; stable release remains blocked.
