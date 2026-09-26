# Performance validation

`scripts/measure-performance.swift` is a local measurement utility, not a
LidPilot product interface. It reads public `proc_pid_rusage` V6 counters;
unsupported/denied reads and replaced PIDs fail the run. It never activates a
session, registers a helper, or changes power/display preferences.

Compile once before measuring:

```sh
xcrun swiftc -O -module-cache-path /private/tmp/lidpilot-metrics-cache \
  scripts/measure-performance.swift -o /private/tmp/lidpilot-measure-performance
```

For each of Off, Keep Screen On and Keep Mac Running, establish and record the
actual mode, build/source revision, app/helper PIDs, Mac/OS, power, lid and
topology first. Let startup/registration settle, dismiss the popover and finish
local builds or other CPU-heavy validation. Run the recorder for 600 seconds
with the app and helper PIDs. Choose a new output file for each run:

```text
/private/tmp/lidpilot-measure-performance 600 MODE OUTPUT.json APP_PID HELPER_PID
```

Retain raw samples with the gate record. The recorder samples every five
seconds and records physical footprint, not RSS. CPU comes from cumulative
Mach-time user/system counters, including reaped child commands, divided by the
elapsed Mach-time interval. Values represent percent of one CPU core. Record
sampled mean and maximum combined physical footprint; neither is a claim about
every transient allocation. A process exit/read failure invalidates this run.

V1 acceptance (owner revision, September 26): average inclusive CPU at most
1.0% of one core over the installed 600-second run, including app, helper and
children; steady app/helper physical footprint at most 75 MiB. There must be
no sustained busy-loop or runaway behavior. Preserve all state verification,
watchdog, lease, fencing, conflict and recovery semantics. The previous 0.2%
aspirational budget is a V1.1/post-V1 optimization goal, not the V1 gate. Keep pending UI feedback below 100 ms, measured
separately with an event/render trace. Do not infer rendered response latency
from this process sampler or a computer-use round-trip duration.

Interrupt/package-idle wakeup rates and available nanojoule counters are
supplemental energy evidence. A zero energy counter may be unavailable
accounting; it is not proof of zero energy. These counters are not Activity
Monitor's proprietary Energy Impact score. Keep any Instruments/Activity
Monitor observations separately labelled and preserve unavailable metrics.

Calibration on the September 21 host used disposable two-second idle and busy
processes: 0.00% and 99.50% of one core respectively, with nonzero physical
footprints. This checks CPU units and sampling behavior; it is not LidPilot's
ten-minute performance result. Calibration files are under
`/private/tmp/lidpilot-metric-check-oi4xgqiw`.
