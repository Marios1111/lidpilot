# V1 audit closeout — September 25

Starting checkout: clean `dev` at `f89cfec0edc2a28bff4c25ab4d6fabf4eafd757c`.
The owner's audit is a read-only assessment pinned to that commit, not new
hardware evidence. The attached updated blueprint is audit edition 1.2 (30
pages), SHA-256 `6710c7c91e79d313963403b854094836fa2e20edceb004951e3e750109315c41`.
The original product blueprint remains the basis for the frozen feature scope.
Existing successful crash, lease, signing and RC upgrade evidence is retained.

## Explicit owner decisions

On September 25 the owner accepted these V1 limitations:

- Keeping the screen awake suppresses native idle dimming as well as idle
  display-off. Manual and ambient brightness observations remain valid; no
  independent dim-without-display-off capability is claimed.
- Update discovery/checks wait until Off. Installation remains manual and
  blocked during a session. Deferred automatic checking still needs validation.
- Built-in panel darkness was observed after roughly one minute, not immediately.
  This is a physical observation, not proof of electrical panel shutdown.
- V1 display support is restricted to the tested built-in-display configuration.
  External displays, docks, virtual and multiple-display setups are unvalidated
  and deferred; this is a reviewed support restriction, not a test pass.
- A genuine different-team signed-client test is deferred independent security
  evidence. Its absence alone does not block V1, provided exact publisher Team
  ID plus bundle identifier/signing requirements remain enforced and existing
  wrong-ID, ad-hoc, malformed-client, console-user and signed-helper tests pass.
  No signing requirement may be weakened, and no different-team pass is claimed.

Stable supported-OS runtime evidence, the hard CPU target, final candidate,
recovery/lifecycle faults and updater/uninstall checks remain unresolved.

## Installed RC6 diagnostic Save dialog

Installed app/helper: production IDs, Developer ID team `L69774LN97`, build 6,
source `5a44e31a0e7a90cf3fb20476c265fff05522cec3`, instrumentation enabled.
App PID 47686; helper PID 49022; launchd parent bundle version 6. Before the
bounded test, independent `pmset -g` read `SleepDisabled=0` and there were no
LidPilot assertions. AC connected, lid open, battery charging (12–15%), thermal
fair. A 30-minute Keep Mac Running session was started through the native UI.

The real diagnostic Save dialog remained visible across the retained
14:21:35–14:23:06 UTC observation (90.69 seconds). All 19 independent samples
showed the override on and the app's system assertion present. Instrumentation
recorded 5 heartbeat firings and 10 successful helper lease renewals during
that interval. Thus the suspected renewal starvation was **not reproduced**
on this RC6/host combination; no speculative modal rewrite was made.

A Cancel action was issued through Computer. The owner also reported saving
at the dialog's selected temporary location; that output file has not yet
been independently located, so the save branch is not counted as verified.
After the dialog closed, the native panel truthfully showed Session active.
Turn Off returned it to Off/Normal macOS behavior; independent read-back at
14:25:58 UTC showed `SleepDisabled=0` and no LidPilot assertion.

Local evidence:

- `/private/tmp/lidpilot-rc6-save-dialog-power.json`, SHA-256
  `fc108dce511fc4ec3f82ada507371b43cd9b4c49b5abf0ab2191a9f889ebfdd6`.
- `/private/tmp/lidpilot-rc6-save-dialog.ndjson`, SHA-256
  `e0c0eab1fd7bdec5b858c5ac713cc8fa1e16093aac69d3857a6e6aa2e09fd572`.

## Remaining bounded work

1. Separate development identities/local ownership records while keeping the
   existing global command fence shared with production; preserve RC identities.
2. Finish the deterministic save branch and final-candidate dialog regression.
3. Build exact RC6 without profiling, install it safely, and retain the matched
   600-second full-process-tree baseline. Attribute installed-root read cost and
   hidden UI overhead before selecting one justified optimization.
4. Repeat all relevant checks on the changed candidate; retain the ≤0.2% CPU gate.
   If no safe candidate meets it, present measured options for owner review.
5. Complete achievable recovery/updater/notification/uninstall fault cases and
   final UI/accessibility/latency checks. No stable publication while mandatory
   gates remain open.
