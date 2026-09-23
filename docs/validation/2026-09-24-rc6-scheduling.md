# RC6 scheduling candidate — performance validation pending

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
  passed for the candidate source.

RC5 was Off with independent SleepDisabled=0 and no LidPilot assertions after
the last comparison. Its normal Remove Helper action showed Not installed,
and launchd no longer had its service. The app quit and its PID exited. The
old bundle is retained at `/private/tmp/LidPilot-RC5-rollback-20260924.app`.
RC6 was copied to `/Applications/LidPilot.app` and launched. Installed strict
deep signature, staple validation, and Gatekeeper assessment passed; installed
bundle build is 6 and independent SleepDisabled remains 0. This local
replacement is not Sparkle upgrade evidence.

Replacement helper registration is pending the native Settings window. Next:
verify matching helper and Standard launchd configuration, then run the same
installed 600-second process-tree capture. Energy/response comparison and a
final uninstrumented run remain mandatory. Performance is not passed; stable
release remains blocked. The temporary diagnostic LaunchAgents were removed.
