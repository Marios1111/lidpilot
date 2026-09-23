# RC4 performance investigation

Source checkpoint: `c3c9cd5` on `dev`; installed app remains RC4/build 4,
built from `94cf711`. This is an investigation, not a passing release gate.
The owner reaffirmed the hard ≤0.2% of one-core, 600-second inclusive CPU
target and prohibited weaker watchdog, verification, safety, conflict, or
recovery behavior.

## Evidence and measurement boundaries

The retained RC4 measurement in [the candidate record](2026-09-24-rc4.md)
includes app PID 19350, helper PID 19359, and the helper's reaped children:
about 0.102% app, 0.064% helper, and 0.519% child CPU, totaling 0.684%.
The app/helper PIDs were independently rechecked for this investigation.
The baseline was AC attached, lid open, `SleepDisabled=0`, with no LidPilot
assertion; the native panel also showed Off before the profiling session.

The steady source path has a watchdog read every 10 seconds and two reads per
15-second renewal (preflight and reply). That accounts for approximately 140
reads per 600 seconds before extra notification-driven reconciliations.
This is a source-derived estimate, not an observed launch count. The two
reads can detect a flag change between preflight and reply; removing one
requires an explicit safety argument and relevant regression evidence.

A separate console-user microbenchmark performed 60 serial fixed `pmset -g`
reads with the production command environment. It measured 0.111335 seconds
child user CPU and 0.172817 seconds child system CPU over 0.473588 seconds
wall time. It neither measures the installed root helper nor substitutes for
the ten-minute gate. Its difference from the installed measurement is a
reason to trace actual launches before predicting an optimization's effect.
Raw local result: `/private/tmp/lidpilot-pmset-read-microbenchmark-20260924.json`.

## Public read-back investigation

The lead retained architecture ownership; GPT-6 Luna Max performed bounded
read-only API research. CodeGraph and current source supplied call-path context.

Apple's published [pmset source](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmset/pmset.m)
includes private IOKit headers and reads `SleepDisabled` through
`IOPMCopySystemPowerSettings` and `kIOPMSleepDisabledKey`. Neither declaration
was found in the installed public SDK's IOKit headers. No documented public
equivalent or change notification for that live override was found in the
[IOPMLib API surface](https://developer.apple.com/documentation/iokit/iopmlib_h).
`IOPMSleepEnabled` describes support for full sleep versus doze; assertion APIs
do not report this global override. Watching preferences cannot certify the
live applied value. Public generic IORegistry access would still depend on an
undocumented property contract. No such replacement has been adopted.

The root `execsnoop` attempt failed because the `proc:::exec-success` probe
is unavailable with SIP enabled. SIP remains enabled. Bounded Apple
`fs_usage -f exec` traces filtered first by helper PID (120 seconds), then
by `pmset` name (60 seconds), produced empty files. These are unsuccessful
observations, not evidence of zero launches. The session was visibly active
and independent read-back confirmed the override and system assertion.
Afterward, the native Turn Off action returned the panel to Off. Independent
read-back confirmed `SleepDisabled=0` and no LidPilot wake assertion.

The next useful profiling step is an explicitly instrumented signed candidate
that records read-call origins/counts without altering verification behavior.
No runtime optimization or new ten-minute gate pass is claimed here. In
particular, the microbenchmark does not establish that the target is impossible
or achievable in an installed settled session.

A request-local renewal coalescing proposal was also rejected before adoption.
The existing `renewalReplyReadbackAndWatchdogHandleFlagDrift` regression proves
that the second read detects an external change after preflight. Reusing the
preflight observation would defer that detection to the next watchdog tick.
Although the timer itself would be unchanged, this weakens reply-time state
verification and conflicts with the owner's explicit constraint. The original
runtime and regression remain in place.

## Recorder improvement

Commit `af4cb2a` adds per-target user/system/reaped-child tick deltas and the
Mach timebase to the local performance report. Sampling and aggregate CPU
semantics remain unchanged. GPT-6 Luna Max implemented this bounded tool
change; the lead reviewed the diff. Optimized compilation passed, as did a
5.003-second ordinary-process smoke run and a 5.005-second parent/child run
with nonzero reaped-child CPU. Per-target percentages summed to the existing
aggregate in both runs. These smoke checks do not pass the installed gate.

## Unavailable release prerequisites

The owner reconfirmed that no external display/dock and no separate Apple
Developer Team signing identity are available. G2 external/dock coverage and
the genuine different-team G4 rejection test remain BLOCKED. Prior built-in
display or wrong-identifier/ad-hoc tests do not satisfy these cases. No stable
tag, `main` release merge, stable feed, or final artifact publication is
authorized by the current evidence.
