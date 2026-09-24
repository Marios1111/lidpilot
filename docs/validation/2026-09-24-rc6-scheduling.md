# RC6 scheduling candidate — performance gate failed

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

RC6's signed helper was Approved through native Helper & Recovery Settings.
A native Refresh showed Session Off and override off. Independent read-back
showed SleepDisabled=0 and no LidPilot assertion. launchd reported a running
root daemon PID 49022, parent bundle version 6, with installed Standard plist;
the helper team and identifier matched the expected signed publisher.

## Installed 600-second comparison

The owner started the same root recorder used for RC5. Lid open, AC attached,
Keep Mac Running active, panel/Settings closed; app PID 47686, helper PID 49022.
Independent preflight showed SleepDisabled=1, a LidPilot system-sleep assertion,
and no display assertion. Window: 2026-09-23 23:51:22.375209 UTC, lasting
600.000493 seconds. No runtime code, safety timing or configuration changed
during capture.

| Measurement | RC5 Background | RC6 Standard | Change |
| --- | ---: | ---: | ---: |
| App CPU, % one core | 0.119883 | 0.119547 | -0.000336 |
| Helper own CPU, % | 0.071385 | 0.060163 | -0.011223 |
| Reaped `pmset` child CPU, % | 0.422660 | 0.363308 | -0.059353 |
| **Total CPU, %** | **0.613929** | **0.543018** | **-0.070911** |
| Read launches | 148 | 144 | -4 |
| Mean physical memory, MiB | 52.282 | 52.561 | +0.279 |
| Interrupt wakeups/s | 0.5400 | 0.4533 | -0.0867 |
| Package idle wakeups/s | 0.0417 | 0.0400 | -0.0017 |

The recorder also reported energy counters of 192,427,594 nJ for RC5 and
171,100,657 nJ for RC6. These are the recorder's app/helper process counters,
not whole-system or child-process energy and not Activity Monitor's Energy
Impact score. They cannot establish a net energy improvement. UI response was
not quantitatively measured in this run.

| `pmset` read origin | RC5 calls | RC6 calls | RC6 child CPU % |
| --- | ---: | ---: | ---: |
| Scheduled 10-second watchdog | 60 | 60 | 0.164299 |
| Renewal admission watchdog | 44 | 42 | 0.112736 |
| Fresh renewal reply | 44 | 42 | 0.087494 |
| **Total** | **148** | **144** | **0.364529** |

The profile reported 39 heartbeat firings, 42 renewals, 42 reconciliations,
three observer callbacks and 84 hidden-panel timeline body evaluations. All
144 launches in the measurement window were reads. No profile sequence gaps,
unmatched spans or boundary spans were found; child getrusage and recorder
counts differ by about 0.0012 percentage points. The launchd change improved
CPU by 0.071 percentage points but the hard ≤0.2% target still **FAILS**.
The scheduled watchdog alone costs 0.164% in child CPU; its ten-second cadence
and live state verification must not be weakened to manufacture a pass.

Afterward, native Turn Off showed Off/Normal macOS behavior. Independent
`pmset -g` read SleepDisabled=0 and `pmset -g assertions` showed no LidPilot
assertion. The build-6 helper remained registered. The task-owned diagnostic
log stream was stopped after cleanup.

Raw local trace: `/private/tmp/lidpilot-rc6-installed-profile.ndjson` SHA-256
`c60af2d7eac27070f71c7d0311741c2fd7e1131756061c19d3623a2fce9a3d62`.
Committed recorder SHA-256:
`2aae0057ec409d9fbd39e9bdea27175cb633eac4fc31b725b4afed87ddf28bd1`.
The full recorder and parsed attribution are in `evidence/rc6-profile-*`.
The temporary diagnostic LaunchAgents were removed. A next optimization needs
another controlled experiment targeting command scheduling/child CPU without
replacing independent read-backs or reducing watchdog timing. A final
uninstrumented 600-second installed result and energy/response check are still
mandatory; no stable release is authorized.


## Follow-up read-only QoS isolation

The RC6 trace identifies the remaining origins and their direct child CPU:
60 scheduled watchdog reads (0.164299% of one core), 42 renewal-admission
reads (0.112736%), and 42 reply-time reads (0.087494%). These are fresh
`pmset -g` observations. The scheduled watchdog and reply reads are required
for the existing safety and drift guarantees; admission reads protect lease
validation before renewal. Reusing a stale read for the reply is explicitly
rejected by the regression test and would weaken drift detection.

A bounded extension of the fixed, read-only benchmark compared queue QoS in
otherwise identical disposable **Standard user LaunchAgents** while LidPilot
was Off. Each ran 60 fixed reads (five warmups, 55 measured) at UID 501.
Default QoS averaged **5.195 ms/read**; utility QoS averaged **5.760 ms/read**.
All parsed states were Off. Both temporary jobs were booted out. This small
controlled difference cannot explain the installed root helper's roughly
15.18 ms/read, and it is not evidence for increasing production queue QoS.
The root launchd job, fence descriptor, app activity and system load differ;
actual child core placement remains unmeasured. No second optimization has
been made. A supported, efficient live-state getter or another verified
structural reduction would be needed before the 0.2% target can be claimed.
Do not cache success, weaken the watchdog, drop independent post-write reads,
or infer a performance pass from a microbenchmark.
