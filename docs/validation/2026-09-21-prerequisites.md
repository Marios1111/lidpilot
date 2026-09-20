# Release-validation prerequisites — 2026-09-21

Owner: selected Astra High lead. Starting revision `8cb7fc9`; signing wrapper
fix `0e391f4`. App/runtime source was unchanged for this initial signed build.
The current execution plan is [V1_RELEASE_PLAN.md](../V1_RELEASE_PLAN.md).

## Host and initial state

- MacBook Air, Apple M4, 24 GB; macOS 27.2 (26B5086k); Xcode 27.0 (27A5252f).
- Built-in Color LCD only. No external display or dock is currently available.
- User confirmed the Mac is on an open, ventilated desk and can assist with
  lid/panel observations. This is not a completed panel observation.
- Read-only initial state: lid open, automatic brightness enabled,
  `SleepDisabled=1`, low-power mode `0`, display idle timeout one minute.
- Power initially reported AC while the battery reported 48% and discharging;
  re-sample and apply the actual safety policy before enabling a lease.
- The existing controller received a normal application quit request. It
  exited; its helper remained. The first read-back was still `1`, and a later
  independent `pmset -g` read-back was `0`. No LidPilot/global reset command was
  used. The delay was not instrumented, so no recovery-time bound is claimed.

## Signing and release prerequisites

- Available Developer ID Application identity: team `L69774LN97`.
- Signed Release app and embedded helper both pass strict deep codesign
  verification and report their expected identifiers and the same team.
- The initial build had only a local signing time. The wrapper was corrected
  to request `--timestamp`; rebuilt app and helper now report secure timestamps
  and hardened runtime. This is not notarization acceptance.
- The operator stored `lidpilot-notary` in Keychain. A `notarytool history`
  request authenticated successfully; no credentials were printed or committed.
- A dedicated Sparkle key was generated in Keychain using account
  `com.lidpilot.app.updates`. Its protected backup is outside the repository.
  Only the public key may be committed. Actual RC signatures remain to be tested.
- A scan of 121 reachable historical blob objects found no candidates for the
  checked private-key/token patterns; no credential-file extensions are tracked.
  Pattern scanning is supplemental evidence, not proof against every secret.

## CI and tests

- Initial GitHub CI run `35542304099` failed because `rg` was absent on the
  runner. The portable scanner fix is `cea90f9`; it preserves scan-error failures.
- Fresh Runtime test execution initially produced five descriptor-related
  issues in two command-fence tests. Investigation is pending. Real helper
  activation is held until the failure is explained or fixed.
- Secure signed build log: `/private/tmp/lidpilot-gates-signed-build.log`.
- Initial test log: `/private/tmp/lidpilot-gates-tests.log`.

G1–G5 and performance are not passed by this prerequisite record.
