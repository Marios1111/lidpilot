# RC6 uninstrumented installed baseline — CPU gate failed

Exact app/helper source: `5a44e31a0e7a90cf3fb20476c265fff05522cec3`.
Version 1.0.0, build 6; normal Release without `LIDPILOT_PROFILE`.
This is a matched-source diagnostic baseline, not a new public release.
The working branch was `dev` at `1ba09b2`; uncommitted identity, icon and website
changes were **not** part of the installed app.

## Installed identity and conditions

The Developer ID app was notarized (Accepted submission
`b1d40e98-32d4-40ff-86a5-4379a4d3edc3`), stapled and installed through the normal
helper-removal/re-registration flow. Strict signature, Gatekeeper and staple
checks passed before capture. Production app/helper identifiers and publisher
Team `L69774LN97` were retained. Both installed binaries lacked the profiling
marker. App PID 36984 and root helper PID 38078 remained unchanged throughout.

Host: Apple Silicon M4 MacBook Air, built-in display, macOS 27.2 **26B5091g**.
The earlier instrumented RC6 record used **26B5086k**. The changed beta OS build
and different dates/system conditions prevent causal attribution of the delta
to instrumentation alone. This remains a valid absolute 600-second measurement
on the recorded host, not evidence from a stable OS release. After this run, the
owner explicitly accepted this Mac as the V1 validation host without requiring
a separate stable-OS test. That scope decision does not change this failed CPU
result or the hard ≤0.2% inclusive target.

The operator selected Keep Mac Running and confirmed both windows closed.
Independent preflight showed `SleepDisabled=1`, a LidPilot system-sleep
assertion, no display-sleep assertion, AC power and Low Power Mode off. The lid
remained open. Builds, tests, native UI interaction, video rendering and package
installation were paused during the run. Lightweight source/document work
continued; no runtime code or safety settings changed in the installed app.

The owner executed the existing root recorder in Warp:

```sh
sudo /private/tmp/lidpilot-measure-performance-profile 600 keep-mac-running-rc6-uninstrumented /private/tmp/lidpilot-keep-mac-running-rc6-uninstrumented.json 36984 38078
```

Recorder binary SHA-256:
`f6965c146bea609a59f487532f891f8f18effc1a9196ad5d3c5d792ba2beb95e`.
Capture started September 26 at 17:45:05 UTC and lasted **600.000991 seconds**.

## Results

| Metric | Instrumented RC6 | Uninstrumented RC6 |
| --- | ---: | ---: |
| App CPU, % of one core | 0.119547 | 0.355936 |
| Helper own CPU, % | 0.060163 | 0.054073 |
| Reaped helper child CPU, % | 0.363308 | 0.420460 |
| **Inclusive CPU, %** | **0.543018 FAIL** | **0.830470 FAIL** |
| Mean combined physical memory, MiB | 52.561 | 63.320 PASS |
| Maximum sampled combined memory, MiB | — | 63.548 |
| Interrupt wakeups/s (app + helper) | 0.4533 | 1.0983 |
| Package idle wakeups/s (app + helper) | 0.0400 | 0.2300 |
| Reported process energy, nJ | 171,100,657 | 771,547,182 |
| Measured fixed read count | 144 | Not collected in uninstrumented build |

The hard limit remains **≤0.2% inclusive CPU**; children are not excluded.
Memory passes the ≤75 MiB combined target. Energy/wakeup counters cover the
sampled app/helper processes, not whole-system or child energy and not Activity
Monitor's Energy Impact score. No visible UI latency claim comes from this run.
The prior 144-read count must not be relabelled as a measured count for this run.

The retained [raw recorder](evidence/rc6-uninstrumented-performance.json) has
SHA-256 `9a23cd3cf8dd183508a60df3de3ed93ac429d09772adc640b0be2b448a915a83`.

## Bounded follow-up diagnosis

The app's CPU varied substantially across roughly two-minute intervals
(approximately 0.18%–0.63%); the helper's own cost stayed approximately
0.043%–0.063%, and children approximately 0.35%–0.48%. These intervals are
attribution diagnostics, not alternate acceptance windows.

After the recorder completed, a separate 30-second `sample` capture observed
mostly idle threads, with intermittent SwiftUI/AttributeGraph layout and
accessibility work. This supports investigating retained UI work but does not
quantify its total CPU cost or prove a timer defect. The local stack capture is
`/private/tmp/lidpilot-rc6-uninstrumented-hidden-app.sample.txt`.

The fixed live `pmset` reads remain the largest single component (50.6% of this
run). Even eliminating all app CPU would leave approximately **0.4745%** at the
measured helper/child costs. This is a conditional subtraction, not a universal
lower bound or an achievable measurement. A UI-only change cannot be presented
as evidence that the current run would meet the gate.

No additional runtime optimization has been selected from this baseline.
The prior live-read equivalence investigation, mandatory independent reads,
watchdog timing, leases, fences, conflict and unknown-state handling remain
unchanged. No speculative RC is justified merely by removing instrumentation.

## Cleanup

Immediately after the run, independent read-back still showed Keep Mac Running's
owned override and system assertion, with no display assertion. The native normal Quit action completed cleanup. At 17:59:52 UTC, independent
read-back showed `SleepDisabled=0`, no LidPilot assertion, and the measured app
PID had exited. The signed helper remained registered and idle. The user
confirmed the app had closed. No unrelated assertion or global preference was
cleared.
