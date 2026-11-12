# LidPilot continuity

## 2026-11-12 — Actual notarized release installed; test junk removed

- User explicitly requested replacing the test candidate with the published
  notarized 2.0.3 and cleaning its junk. Homebrew upgrade succeeded; its receipt
  now records 2.0.3. Every installed bundle file/symlink (71 total) matches the
  checksum-verified published ZIP exactly. Gatekeeper reports Notarized
  Developer ID; deep/strict signing and stapled-ticket checks pass.
- User removed the helper, disabled Launch at login and quit before replacement;
  then restored helper approval and Launch at login. Final native CLI read-back:
  app/helper build21, healthy helper, Off, both assertions off, override 0,
  no lease/ownership/recovery. No additional closed-lid/power test was run.
- Removed 60 inactive, owned LidPilot build/cache/temp/duplicate-app items,
  2,126,163,968 allocated bytes (~2.13 GB), after process/open-file checks.
  Includes local build20 duplicates, local build18/19 ZIPs, generated build
  products and temporary release/test workspaces. Source, production preferences,
  signing/Keychain stores, runtime sockets, current Homebrew DMG cache and the
  existing official 2.0.2 rollback ZIP are preserved. A Finder .DS_Store race
  required one targeted cleanup correction; all 60 original targets are gone.
- Compact native screenshots/samples, the read-only probe source, installed
  status and cleanup receipts remain in
  `release-private/validation/2026-11-12/` (~504 KB). Refer to the current
  installation entry in `docs/VERIFICATION.md` for exact installed hashes.
  The earlier publication checkpoint's candidate/backup paths below are historical.

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
- At the initial publication checkpoint, installed app/helper were 2.0.3/build
  21, signed local native-test candidate,
  Approved helper, final Off/both assertions off/flag 0/no ownership or recovery.
  Its build/signing bytes differ from the notarized public archive, despite
  identical source/build number. Do not claim the exact public artifact is
  installed at that checkpoint. Build 20 backups were retained under
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
