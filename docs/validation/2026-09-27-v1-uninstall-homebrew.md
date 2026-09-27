# Stable V1 uninstall, Homebrew installation and restoration

September 27, 2026. Published build 12, source
`af6adf78d4fa776e578132b3111dae11bee536ef`.

1. Native Settings showed Approved helper, Session Off, override off.
2. Original Launch at login On was disabled. Remove Helper was confirmed normally;
   native status became Not installed / Off / override off.
3. Normal Cmd-Q exited the GUI. Independent helper lookup exited 113; no LidPilot
   process remained. SleepDisabled was 0. No unrelated assertion was changed.
4. Stopped bundle moved reversibly to
   `/private/tmp/LidPilot-V1-uninstall-rollback-20260927.app`; Applications absence verified.
5. `HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask Marios1111/tap/lidpilot`
   exited 0 and moved the actual public stable app into Applications. No password
   prompt was needed. Build 12, strict/deep signature, staple and Gatekeeper passed.
6. `brew list --cask --versions lidpilot` reported `lidpilot 1.0.0`.
7. The fresh app had not launched and had no helper/login registration. Actual
   `brew uninstall --cask lidpilot` exited 0, removed Applications/LidPilot.app,
   and purged its cask entry. SleepDisabled remained 0.
8. The same public install command exited 0 again and restored build 12.
9. Relaunch native panel showed Off. Settings restored Launch at login On and
   registered the usual production helper normally. Refresh showed Approved,
   Session Off, override off. Keep Screen On / two hours / notifications Off preserved.
10. Final snapshot: GUI PID 41130, production helper PID 41183, parent bundle build
    12; SleepDisabled=0, no LidPilot assertions, no development instance.

**PASS:** final stable cleanup/removal, actual public Homebrew install/uninstall,
restoration, signed app trust, registered/reachable helper and Off state.
User preferences and bounded diagnostics were preserved. This does not claim
removal of historical macOS Background Items rows or user data.

Earlier noninteractive `--adopt` failed at administrator chmod and rolled back;
it is not success evidence. Fresh installation supersedes it. The published cask
passed style and public DMG hash validation. Full `brew audit` could not run because
this host's Command Line Tools were rejected before the audit; it remains deferred
packaging-tool evidence, with no system toolchain changes or bypasses.
