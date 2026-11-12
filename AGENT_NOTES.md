# LidPilot continuity

## 2026-11-12 — Follow Lid brightness shipped

- User authorized built-in brightness zero while Follow Lid is closed,
  restoration on reopen preserving original/automatic settings, commit/push,
  release and deployment. After public control failed, the user approved a
  narrow private DisplayServices brightness Get/Set exception “if no other
  option”. Public ColorSync supplies UUID identity. No other private controls,
  privileged-helper expansion, external-display blanking or Low Power Mode
  changes were authorized. Low Power Mode remains user-controlled.
- Source/tag: `6894d351d0b07bdbefef64932c225b550b1fcee4` / `v2.0.3`, build 21.
  Stable metadata commit `734022d` followed; final documentation follows that.
  Both `dev` and `main` are updated normally, without force/history rewriting.
- GitHub release 2.0.3, Homebrew tap commit `cea48b0`, website and signed stable
  feed are published. Pages run `43292674416` passed. Canonical public homepage
  advertises 2.0.3; fetched feed/notes/manifest and legacy RC4 feed match tracked
  bytes exactly. App/DMG notarization, staples, Sparkle signatures and all five
  downloaded release files verified. Exact evidence: `docs/VERIFICATION.md`.
- 122 Runtime + 34 Core + 16 app tests, static checks, Debug/signed Release
  builds, native mock rendering/cleanup and source CI `43291110566` pass.
  Publication/docs commits do not change runtime; their automatic CI runs were
  still running at the publication checkpoint, so they are not claimed green.
- User twice confirmed correct brightness on reopening. The second independent
  recorder captured two closed samples at zero then exact restoration to
  0.6548957228660583, with the session still active. Both bounded tests expired
  Off/override off. Full scope/limits:
  `docs/validation/2026-11-12-follow-lid-brightness.md`.
- Installed app/helper: 2.0.3/build 21, signed local native-test candidate,
  Approved helper, final Off/both assertions off/flag 0/no ownership or recovery.
  Its build/signing bytes differ from the notarized public archive, despite
  identical source/build number. Do not claim the exact public artifact is
  installed. Build 20 backups remain under
  `release-private/local-validation/2026-11-12/`; the task-created old app copy
  was moved out of `/Applications` into that rollback folder. Original session
  deadline was saved before replacement and never extended or restarted.
- Brightness restoration is persisted before dimming, targets the same built-in
  UUID, respects newer nonzero changes and runs before renewal on reopen.
  Failure still releases power controls and remains Recovery. Native crash/
  relaunch, other OS/Mac/display combinations and long duration remain untested;
  zero brightness does not prove physical panel power-off.
- Operational findings: tool sandbox hid online displays although the lid was
  open; unsandboxed native reads worked. Durable preferences tests/Xcode caches
  also need approved filesystem access. A detached recorder ended with its
  launcher; use an active exec session for recordings. CUA timed out twice, so
  the user performed helper removal/approval and Quit through native UI.
- Homebrew style requires the recognized tap; the temporary clone's path-only
  check was rejected. Actual clean tap at
  `/opt/homebrew/Library/Taps/marios1111/homebrew-tap` was updated and pushed;
  one cask/no offenses. The installed Homebrew receipt was not changed.
- User requested explicit RTK use. Its output filtering was already active;
  use supported `rtk git`, `rtk gh`, `rtk rg`, and `rtk read` wrappers where useful.
