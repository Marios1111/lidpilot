# LidPilot continuity

## 2026-11-12 — Follow Lid brightness and release (in progress)

- Starting revision: `9b6d4b1` on `dev`, clean, three local commits ahead of
  `origin/dev` (`f55d6f7`); remote main also at `f55d6f7`. Existing local changes
  implement/validate the opt-in Prevent automatic lock behavior. Public release
  remains 2.0.2/build 17; previously installed local candidate was build 20.
- User requests built-in brightness zero while Follow Lid is closed, restoring
  previous brightness on reopen while preserving automatic brightness settings;
  explicitly authorizes commits, push, release and deployment.
- Public `IODisplayGetFloatParameter` probe on this arm64 Mac returned
  `0xe00002c7` (unsupported). `AppleARMBacklight` exists but does not conform to
  `IODisplay`; there are no `IODisplayConnect`/`AppleBacklightDisplay` services.
  Apple IODisplayLib's float setter uses that same unsupported range read.
- After being informed of the repository prohibition and compatibility risk,
  user approved a narrow private DisplayServices exception “if no other option”.
  Only built-in brightness dim/restore is authorized; no privileged-helper
  expansion, external-display blanking, synthetic input or auto-brightness writes.
- Low Power Mode will remain user-controlled: changing overall energy policy is
  unnecessary for dimming and would conflict with the default battery safety pause.
- Read current specification and blueprint (actual PDF path is
  `../Planning/LidPilot_Product_Blueprint_Updated.pdf`, outside the specification
  directory). Zero brightness is not evidence of physical panel power-off.
- Baseline: 103 Runtime + 34 Core tests and `scripts/verify.sh` pass. App tests
  initially hit sandboxed Xcode cache permissions; an approved retry is running.
  Logs: `/private/tmp/lidpilot-20261112-*.log`.
- Release dry-run identifies expected unconfigured signing environment and
  unchanged build 17. Resolve actual signing inputs and new version/build after
  implementation; do not mark hardware approval from mock evidence.

### Implemented and accepted candidate

- `NativeDisplayBrightness` and controller integration now dim only identified
  built-in displays for active Follow Lid/closed samples. Public ColorSync UUID
  identity is revalidated; only brightness Get/Set use private DisplayServices.
  Per-app recovery is saved before mutation, restores only while brightness is
  still zero, and survives restart. Reopening restores before helper renewal;
  cleanup failure still releases power controls and remains visible Recovery.
- 122 Runtime + 34 Core + 16 app tests, static checks, Debug/signed Release builds
  and native mock rendering/cleanup pass. Preferences persistence tests require
  the approved unsandboxed runner; the initial failure was filesystem access.
- Installed 2.0.3/build 21, preserving build 20. User manually removed/approved
  helpers because CUA timed out twice; CLI verified clean Off/override 0 before
  replacement and replacement helper 21 healthy before the approved test.
- User twice confirmed correct brightness on reopen. Corrected second recorder
  captured two closed zero-brightness samples then exact restoration to
  0.6548957228660583; session remained active. First recorder ended with its
  launcher and is not closed-lid evidence. Full record:
  `docs/validation/2026-11-12-follow-lid-brightness.md`.
- Stable 2.0.3/build 21 publication is authorized; signing inputs found in the
  existing protected stores. Final notarization/publication still in progress.
  The earlier active build20 deadline was saved locally before upgrade; never
  restart it beyond its original remaining duration. Test sessions are bounded.

### Distribution checkpoint

- Source/tag `6894d351d0b07bdbefef64932c225b550b1fcee4` / `v2.0.3` is pushed;
  source CI run `43291110566` passed. App and DMG notarization accepted;
  signatures/staples verified. GitHub release published; all five downloaded
  files match the local manifest. Public-assets Pages validation passes.
- Stable metadata replaces the prior single-release feed/notes; historical RC4
  signed bytes and all prior immutable GitHub assets are preserved.
- The installed signed native-test candidate has the same source/build21 but
  differs from final archive/notarization bytes; do not describe it as the exact
  public artifact. Tests expired Off; no prior deadline was extended.
- Homebrew path-only style invocation was rejected because a cask must be in a
  recognized tap. The existing `/opt/homebrew/Library/Taps/marios1111/homebrew-tap`
  was verified clean at `a064e1e`; apply/check/push there. The temporary clone
  remains disposable. No Homebrew global configuration was changed.

- Homebrew cask style passed (one file/no offenses). Tap commit `cea48b0`
  updates only version/URL/DMG hash plus its local continuity note and is pushed.
  Stable Pages publication is the remaining distribution action.
