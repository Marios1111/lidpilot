# V1 release validation execution plan

Started 2026-09-21 from `8cb7fc9` on `dev`, matching `origin/dev`.
The working tree was clean; the previously untracked duplicate driver was absent.
At the start, https://github.com/Marios1111/lidpilot was private and Pages was
not configured. After the owner explicitly approved public RC testing, the
reviewed source, signed RC1, and RC Pages feed were published. `dev` remains the
default branch at that checkpoint. Stable V1.0.0 was subsequently published
on September 27; [VERIFICATION.md](VERIFICATION.md) is the current ledger. This
document retains the original sequence, not a new request to repeat its tests.

The user explicitly authorized real hardware tests, cleanly stopping the other
closed-lid controller, signing/notarization, RC testing, normal development
pushes, and stable publication only after all mandatory gates pass. The lead
is the selected Astra High; bounded tooling work uses Luna Max. V1 scope and
the native UI remain frozen except for evidence-backed fixes.

## Sequence and completion evidence

1. **Repository and CI.** Repair the missing `rg` dependency discovered in run
   `35542304099`, configure actual repository/feed locations, preserve historical
   evidence, and obtain a passing CI run on the tested commit. Review all new
   changes and keep small logical commits.
2. **RC tooling and signing.** Keep numeric bundle versions and increasing build
   numbers; give RC artifacts separate immutable labels and an RC feed. RC
   preparation must never require falsely marking hardware approved. Stable
   release preflight retains every gate. Verify Developer ID signatures,
   hardened runtime, arm64 code, embedded helper identity and bundle structure.
   Generate a dedicated Sparkle key securely and keep private material outside
   tracked source. Validate the operator's notary Keychain profile.
3. **G4 before power mutation.** Install/register the signed helper through
   ServiceManagement, obtain its required user approval, and test reciprocal
   identity, build/protocol compatibility, and invalid-client rejection.
4. **G1/G2 baseline and physical tests.** Record the existing flag and current
   controller; ask it to quit normally and independently verify the resulting
   baseline. Never clear an unowned flag. With the user observing, distinguish
   manual brightness, ambient brightness, inactivity dimming, idle display-off,
   physical panel/backlight state, timestamp-task continuity and reopen behavior.
   User currently has only the built-in display; unavailable topology/OS/model
   cases remain explicitly blocked or outside a reviewed support claim.
5. **G3 recovery.** After ownership and identity are proved, exercise bounded
   finite sessions, GUI loss, helper loss/restart, lease expiry and recovery.
   Use fault injection only where it does not weaken production authentication
   or risk uncontrolled global changes. Retain actual final read-back and
   journal state for each run; mock-only scenarios remain labelled as such.
6. **Performance.** Run separate ten-minute Off, Keep Screen On and Keep Mac
   Running measurements with the popover dismissed and unrelated workload excluded.
   Measure CPU time, app/helper physical footprint, wakeups and pending UI
   latency; do not substitute RSS or instantaneous CPU for the specified metrics.
7. **G5.** Notarize/staple RC artifacts, verify signed archive/feed/notes and
   tamper rejection, perform RC.1 to RC.2 installation with session blocking,
   helper replacement/registration, launch Off and uninstall/cleanup. A private
   Release asset is not an anonymously downloadable Sparkle artifact; resolve
   hosting/publication authority before declaring this gate passed.
8. **Final candidate.** Repeat Debug/Release, full tests, CI, native/accessibility,
   package/signature and applicable hardware checks on the final source. Update
   verification/support/site/release documentation with actual results and
   artifact hashes. Only a fully passing candidate may establish stable `main`,
   `v1.0.0`, the GitHub Release and stable Pages feed; leave `dev` ready for V2.

## Initial prerequisites

- Available host: MacBook Air, Apple M4, 24 GB; macOS 27.2 (26B5086k), Xcode
  27.0 (27A5252f). This does not establish macOS 15 runtime support.
- Developer ID Application identity is available for team `L69774LN97`.
- The operator saved the notarization profile locally; RC1 app and DMG were
  accepted and stapled. No passwords are requested in chat or stored in source.
- Initial observation: lid open, built-in display only, automatic brightness on,
  global sleep override active, AC reported with battery at 48% and discharging.
  Conflicting/transitioning power readings must be reconciled before a lease.
- G1-G5 and performance remain pending until retained evidence supports a result.

Use `VERIFICATION.md` for the latest result, `HARDWARE_VALIDATION.md` for the
procedures, and per-run records under `validation/` for measured evidence.
