# LidPilot focused performance review — extracted evidence

**26 September 2026. Review only: no product changes, builds, tests or Mac measurements performed.**

Repository copy normalizes trailing whitespace in numbered excerpts; the original owner-supplied document remains unchanged.

This companion contains checksum-verified excerpts of the user-provided archive and independently recomputed accounting. It does not substitute current GitHub files for the measured installed source. Line numbers refer to the original individual files inside the ZIP.

Input archive SHA-256: `b7cea93dd5cd18555d3e1a86926b96b339aacc519cfcd14cdc611c9b444aa483`. All 83 manifest entries match. The archive contains no installed app binaries, so the documented source-to-binary identity is not independently attested by this review.

## Recomputed measurement arithmetic

CPU percent = 100 × (app own CPU seconds + helper own CPU seconds + non-overlapping reaped-child CPU seconds) / elapsed seconds. Raw ticks use the recorded Mach timebase; CPU is not divided by the number of cores.

| Record | CPU seconds | Elapsed seconds | CPU % of one core | Samples |
|---|---:|---:|---:|---:|
| rc5-profile-measurement.json | 3.683603042 | 600.004894667 | 0.613928832 | 121 |
| rc6-profile-measurement.json | 3.258108792 | 600.000492708 | 0.543017686 | 121 |
| rc6-uninstrumented-performance.json | 4.982826792 | 600.000991208 | 0.830469760 | 121 |

All retained sample PID-start identities are consistent and counters are monotonic. Reaped-child accounting remains boundary-sensitive; the uninstrumented record does not contain a read count or command-boundary trace. No unit conversion or summation error was found that reverses the gate result. Do not label the instrumented/uninstrumented comparison environment-matched: the OS build changed.

## Review findings and scope

1. The existing CPU result remains FAIL. The uninstrumented record uses about 4.983 CPU seconds versus a 1.2 CPU-second budget over 600 seconds.
2. `pmset` child cost is distinct from the helper wait-loop cost; a helper-only change cannot simply claim savings already charged to a different PID.
3. Reply freshness is guarded by a second read; do not coalesce admission and reply samples.
4. `TimelineView` is already paused when the panel is marked not visible. A paused animation schedule does not establish zero parent/observation-driven body work, but 84 hidden evaluations do not establish an unpaused 1 Hz loop.
5. A completed XPC request leaves a scheduled timeout closure that later does no useful continuation work. This is provably redundant work, with unmeasured and likely small savings.
6. The runner ignores both EOF and `POLLHUP` while `waitpid(..., WNOHANG)` reports a still-running child. A closed pipe can therefore cause repeated immediately returning polls. This is a source-derived edge-case defect, not a measured explanation of all child CPU.
7. Apple’s published `IOPMCopySystemPowerSettings` implementation copies a preferences dictionary. The CLI observation is not a documented kernel-applied acknowledgment. This is a source-derived semantic limitation; the exact shipped beta implementation is not contained in this archive.
8. No documented equivalent cheaper reader was identified. Direct private-symbol calls or use of public generic APIs with undocumented power preference/registry keys remain excluded.

## Recommended single experiment — hidden-presentation A/B/A

Proposed, not performed: build a local baseline from the measured source and a candidate differing only in visibility-scoped presentation mounting/subscriptions. Keep the model, helper binary, real commands, assertions, observers, renewal/read cadence and recovery code unchanged. Remove hidden popover/settings presentation dependencies when windows are actually closed, but keep the status indicator, explicit Stop and runtime alive; recreate current UI when shown. No fake reader and no suppressed safety updates.

Run A1, B, A2 for 600 seconds each on the same current accepted host, OS build, toolchain, mode, AC state and window-interaction history. Use uninstrumented Release configurations and identical accounting. Record app/helper/children separately. Diagnose using a separate short trace, not an always-on tracer during acceptance. The falsifiable expectation is that B reduces app CPU beyond A1/A2 drift; it does not predict elimination of child CPU or a full 0.2% pass. A useful provisional effect threshold is 0.05 percentage points below both bracketing app results and larger than their mutual difference; this is an experiment decision rule, not a release requirement or confidence interval.

If the effect is absent or confounded, close the hypothesis instead of producing another published RC. If the total remains above 0.2%, report FAIL even if app CPU improves. At unchanged measured helper/child costs, UI-only work leaves roughly 0.4745% CPU. All release acceptance still requires the actual complete result and preserved behavior.

## External primary sources checked

- Apple IOKitUser, pinned `323ead896d04424f87184d8f6ff0cce811aab106`, `pwr_mgt.subproj/IOPMEnergyPrefs.c`, System Power Settings section: https://github.com/apple-oss-distributions/IOKitUser/blob/323ead896d04424f87184d8f6ff0cce811aab106/pwr_mgt.subproj/IOPMEnergyPrefs.c
- Apple PowerManagement, pinned `d415e45501842834a280930c3eed9186544a67f0`, pmset.m: https://github.com/apple-oss-distributions/PowerManagement/blob/d415e45501842834a280930c3eed9186544a67f0/pmset/pmset.m
- Apple XNU task CPU accounting: https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/task.c
- Apple XNU rusage export: https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/bsd_kern.c
- Apple XNU child aggregation: https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_resource.c
- Apple public IOPMLib API catalogue: https://developer.apple.com/documentation/iokit/iopmlib_h
- Apple IOPMSleepEnabled semantics: https://developer.apple.com/documentation/iokit/1557074-iopmsleepenabled
- Apple Observation dependencies: https://developer.apple.com/documentation/SwiftUI/Managing-model-data-in-your-app
- Apple process-exit dispatch source: https://developer.apple.com/documentation/dispatch/dispatchsourceprocess
- Apple poll documentation: https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/poll.2.html

## Source excerpt index

- [S1: Provenance](#s1) — `READ-ME-FIRST.txt`
- [S2: Recorder sampling and accounting](#s2) — `evidence/scripts/measure-performance.swift`
- [S3: Uninstrumented measurement record](#s3) — `evidence/docs/validation/2026-09-26-rc6-uninstrumented.md`
- [S4: Trace completeness condition](#s4) — `evidence/scripts/analyze-performance-profile.py`
- [S5: Helper read placement](#s5) — `installed-rc6-source/Runtime/HelperEngine.swift`
- [S6: Tests that protect reply-time drift observation](#s6) — `installed-rc6-source/Tests/HelperEngineTests.swift`
- [S7: Helper scheduling and request serialization](#s7) — `installed-rc6-source/Runtime/HelperService.swift`
- [S8: Coordinator observation/publication path](#s8) — `installed-rc6-source/Runtime/SessionController.swift`
- [S9: Heartbeat schedule](#s9) — `installed-rc6-source/App/AppModel.swift`
- [S10: Hidden presentation and paused timeline](#s10) — `installed-rc6-source/App/PilotPanel.swift`
- [S11: Window ownership](#s11) — `installed-rc6-source/App/LidPilotApp.swift`
- [S12: Uncancelled completed-request timeout](#s12) — `installed-rc6-source/Runtime/HelperTransport.swift`
- [S13: Command runner EOF/HUP control flow](#s13) — `installed-rc6-source/Runtime/PMSetDriver.swift`
- [S14: Assertion maintenance](#s14) — `installed-rc6-source/Runtime/PowerAssertions.swift`
- [S15: Repeated native system sampling](#s15) — `installed-rc6-source/Runtime/SystemState.swift`

<a id="s1"></a>
## S1 — Provenance

File: `READ-ME-FIRST.txt`
SHA-256: `768f881a45a7824dc308d4b5a376fb37c626672a0dc96bb3242c0eb5758273e9`

Original lines 1–11:
```text
   1  LidPilot CPU investigation context, 2026-09-26
   2
   3  Measured installed RC6 source: 5a44e31a0e7a90cf3fb20476c265fff05522cec3
   4  Current local dev HEAD: 5e9420ed1eb9fba9045b05f4b0c701a66fe6b57b
   5  Current-worktree includes two additional uncommitted read-failure tests; it is NOT the measured installed binary. Unrelated identity/icon/UI changes are not a measured performance optimization.
   6
   7  Read the three RC5/RC6 records and latest uninstrumented record before source. Distinguish 600-second installed measurements from burst microbenchmarks. The OS build changed between the instrumented and uninstrumented runs, so the comparison is source-matched, not environment-matched.
   8
   9  Current host is an M4 MacBook Air, built-in display, macOS 27.2 beta 26B5091g. Owner explicitly accepts this host for V1; do not require another OS to avoid the CPU question. Hard target is <=0.2% of one core including app, helper, and children. Current uninstrumented result is 0.830470%. Memory passes. No safe supported optimization has yet demonstrated a pass.
  10
  11  This focused archive contains source and retained measurements only, no signing private material, tokens, notarization credentials, or app binaries. No stable V1 release is approved.
```


<a id="s2"></a>
## S2 — Recorder sampling and accounting

File: `evidence/scripts/measure-performance.swift`
SHA-256: `ec9983777fc5de46573fbb39fb53ed647d399cc49acf97b2f699c6cf4434e582`

Original lines 49–65:
```text
  49  func read(_ pid: Int32) throws -> Reading {
  50      var info = rusage_info_v6()
  51      let result = withUnsafeMutablePointer(to: &info) {
  52          $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
  53              proc_pid_rusage(pid, RUSAGE_INFO_V6, $0)
  54          }
  55      }
  56      guard result == 0 else {
  57          throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno),
  58                        userInfo: [NSLocalizedDescriptionKey: "Cannot read PID \(pid); no measurement result may be inferred."])
  59      }
  60      return Reading(pid: pid, started: info.ri_proc_start_abstime,
  61                     userTicks: info.ri_user_time, systemTicks: info.ri_system_time,
  62                     childUserTicks: info.ri_child_user_time, childSystemTicks: info.ri_child_system_time,
  63                     physicalBytes: info.ri_phys_footprint,
  64                     interruptWakeups: info.ri_interrupt_wkups, idleWakeups: info.ri_pkg_idle_wkups,
  65                     energyNanojoules: info.ri_energy_nj)
```

Original lines 82–108:
```text
  82      var timebase = mach_timebase_info_data_t()
  83      guard mach_timebase_info(&timebase) == KERN_SUCCESS else { throw NSError(domain: "clock", code: 1) }
  84      guard timebase.numer > 0, timebase.denom > 0 else {
  85          throw NSError(domain: "clock", code: 1,
  86                        userInfo: [NSLocalizedDescriptionKey: "Mach returned an invalid timebase"])
  87      }
  88      let secondsPerTick = Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
  89      guard secondsPerTick.isFinite, secondsPerTick > 0 else {
  90          throw NSError(domain: "clock", code: 1,
  91                        userInfo: [NSLocalizedDescriptionKey: "Mach timebase cannot be converted to seconds"])
  92      }
  93      let startedAt = Date()
  94      let start = mach_absolute_time()
  95      let initial = try pids.map(read)
  96      var samples = [Sample(elapsedSeconds: 0, processes: initial)]
  97      while true {
  98          let elapsed = Double(mach_absolute_time() - start) * secondsPerTick
  99          if elapsed >= duration { break }
 100          Thread.sleep(forTimeInterval: min(5, duration - elapsed))
 101          let values = try pids.map(read)
 102          guard zip(values, initial).allSatisfy({ $0.started == $1.started }) else {
 103              throw NSError(domain: "process", code: 1, userInfo: [NSLocalizedDescriptionKey: "A target PID was replaced; discard this run"])
 104          }
 105          samples.append(Sample(elapsedSeconds: Double(mach_absolute_time() - start) * secondsPerTick,
 106                                processes: values))
 107      }
 108      let elapsed = samples.last!.elapsedSeconds
```

Original lines 134–174:
```text
 134      func delta(_ field: KeyPath<Reading, UInt64>, name: String) throws -> UInt64 {
 135          var total: UInt64 = 0
 136          for (last, first) in zip(final, initial) {
 137              let amount = try difference(last[keyPath: field], first[keyPath: field], field: name, pid: first.pid)
 138              total = try checkedAdd(total, amount, field: name)
 139          }
 140          return total
 141      }
 142      // CPU accounting uses Mach absolute-time units. Include reaped power-command
 143      // children; do not substitute wall time or relabel these counters as ns.
 144      var cpuByTarget = [TargetCPU]()
 145      var cpuTicks: UInt64 = 0
 146      for (last, first) in zip(final, initial) {
 147          let user = try difference(last.userTicks, first.userTicks, field: "user CPU", pid: first.pid)
 148          let system = try difference(last.systemTicks, first.systemTicks, field: "system CPU", pid: first.pid)
 149          let childUser = try difference(last.childUserTicks, first.childUserTicks,
 150                                         field: "reaped-child user CPU", pid: first.pid)
 151          let childSystem = try difference(last.childSystemTicks, first.childSystemTicks,
 152                                           field: "reaped-child system CPU", pid: first.pid)
 153          let targetTicks = try checkedAdd(try checkedAdd(user, system, field: "target CPU"),
 154                                           try checkedAdd(childUser, childSystem, field: "reaped-child CPU"),
 155                                           field: "inclusive target CPU")
 156          cpuTicks = try checkedAdd(cpuTicks, targetTicks, field: "inclusive process-tree CPU")
 157          cpuByTarget.append(TargetCPU(pid: first.pid, ownUserTicks: user, ownSystemTicks: system,
 158                                       reapedChildUserTicks: childUser, reapedChildSystemTicks: childSystem,
 159                                       inclusiveCPUPercentOfOneCore:
 160                                          Double(targetTicks) * secondsPerTick / elapsed * 100))
 161      }
 162      let memory = samples.map { $0.processes.reduce(0.0) { $0 + Double($1.physicalBytes) } / 1_048_576 }
 163      let report = Report(label: args[1], startedAt: startedAt,
 164                          startedAtUnixSeconds: startedAt.timeIntervalSince1970,
 165                          endedAtUnixSeconds: Date().timeIntervalSince1970, durationSeconds: elapsed,
 166                          machTimebaseNumerator: timebase.numer, machTimebaseDenominator: timebase.denom,
 167                          cpuPercentOfOneCoreIncludingReapedChildren: Double(cpuTicks) * secondsPerTick / elapsed * 100,
 168                          cpuByTarget: cpuByTarget,
 169                          meanCombinedPhysicalMiB: memory.reduce(0,+) / Double(memory.count),
 170                          maxSampledCombinedPhysicalMiB: memory.max()!,
 171                          interruptWakeupsPerSecond: Double(try delta(\.interruptWakeups, name: "interrupt wakeup")) / elapsed,
 172                          packageIdleWakeupsPerSecond: Double(try delta(\.idleWakeups, name: "package idle wakeup")) / elapsed,
 173                          reportedEnergyNanojoules: try delta(\.energyNanojoules, name: "energy"),
 174                          notes: "Public proc_pid_rusage V6; 5-second samples. CPU tick fields are converted using the recorded Mach timebase numerator/denominator. Per-target inclusive CPU includes that PID's reaped children and sums to the combined value when target process trees do not overlap. Zero energy counters may mean unavailable accounting, not zero energy. This is not Activity Monitor's Energy Impact score. PID restarts, nonmonotonic counters or read failures invalidate the run. Physical footprint is sampled, not an absolute transient peak. Record mode, build, power and display state separately; this tool cannot verify them.",
```


<a id="s3"></a>
## S3 — Uninstrumented measurement record

File: `evidence/docs/validation/2026-09-26-rc6-uninstrumented.md`
SHA-256: `42a477ff95f7cd3285150a89c633ab3b62e98a22acc3b60f08c58735f6e460a8`

Original lines 3–32:
```text
   3  Exact app/helper source: `5a44e31a0e7a90cf3fb20476c265fff05522cec3`.
   4  Version 1.0.0, build 6; normal Release without `LIDPILOT_PROFILE`.
   5  This is a matched-source diagnostic baseline, not a new public release.
   6  The working branch was `dev` at `1ba09b2`; uncommitted identity, icon and website
   7  changes were **not** part of the installed app.
   8
   9  ## Installed identity and conditions
  10
  11  The Developer ID app was notarized (Accepted submission
  12  `b1d40e98-32d4-40ff-86a5-4379a4d3edc3`), stapled and installed through the normal
  13  helper-removal/re-registration flow. Strict signature, Gatekeeper and staple
  14  checks passed before capture. Production app/helper identifiers and publisher
  15  Team `L69774LN97` were retained. Both installed binaries lacked the profiling
  16  marker. App PID 36984 and root helper PID 38078 remained unchanged throughout.
  17
  18  Host: Apple Silicon M4 MacBook Air, built-in display, macOS 27.2 **26B5091g**.
  19  The earlier instrumented RC6 record used **26B5086k**. The changed beta OS build
  20  and different dates/system conditions prevent causal attribution of the delta
  21  to instrumentation alone. This remains a valid absolute 600-second measurement
  22  on the recorded host, not evidence from a stable OS release. After this run, the
  23  owner explicitly accepted this Mac as the V1 validation host without requiring
  24  a separate stable-OS test. That scope decision does not change this failed CPU
  25  result or the hard ≤0.2% inclusive target.
  26
  27  The operator selected Keep Mac Running and confirmed both windows closed.
  28  Independent preflight showed `SleepDisabled=1`, a LidPilot system-sleep
  29  assertion, no display-sleep assertion, AC power and Low Power Mode off. The lid
  30  remained open. Builds, tests, native UI interaction, video rendering and package
  31  installation were paused during the run. Lightweight source/document work
  32  continued; no runtime code or safety settings changed in the installed app.
```

Original lines 44–90:
```text
  44  ## Results
  45
  46  | Metric | Instrumented RC6 | Uninstrumented RC6 |
  47  | --- | ---: | ---: |
  48  | App CPU, % of one core | 0.119547 | 0.355936 |
  49  | Helper own CPU, % | 0.060163 | 0.054073 |
  50  | Reaped helper child CPU, % | 0.363308 | 0.420460 |
  51  | **Inclusive CPU, %** | **0.543018 FAIL** | **0.830470 FAIL** |
  52  | Mean combined physical memory, MiB | 52.561 | 63.320 PASS |
  53  | Maximum sampled combined memory, MiB | — | 63.548 |
  54  | Interrupt wakeups/s (app + helper) | 0.4533 | 1.0983 |
  55  | Package idle wakeups/s (app + helper) | 0.0400 | 0.2300 |
  56  | Reported process energy, nJ | 171,100,657 | 771,547,182 |
  57  | Measured fixed read count | 144 | Not collected in uninstrumented build |
  58
  59  The hard limit remains **≤0.2% inclusive CPU**; children are not excluded.
  60  Memory passes the ≤75 MiB combined target. Energy/wakeup counters cover the
  61  sampled app/helper processes, not whole-system or child energy and not Activity
  62  Monitor's Energy Impact score. No visible UI latency claim comes from this run.
  63  The prior 144-read count must not be relabelled as a measured count for this run.
  64
  65  The retained [raw recorder](evidence/rc6-uninstrumented-performance.json) has
  66  SHA-256 `9a23cd3cf8dd183508a60df3de3ed93ac429d09772adc640b0be2b448a915a83`.
  67
  68  ## Bounded follow-up diagnosis
  69
  70  The app's CPU varied substantially across roughly two-minute intervals
  71  (approximately 0.18%–0.63%); the helper's own cost stayed approximately
  72  0.043%–0.063%, and children approximately 0.35%–0.48%. These intervals are
  73  attribution diagnostics, not alternate acceptance windows.
  74
  75  After the recorder completed, a separate 30-second `sample` capture observed
  76  mostly idle threads, with intermittent SwiftUI/AttributeGraph layout and
  77  accessibility work. This supports investigating retained UI work but does not
  78  quantify its total CPU cost or prove a timer defect. The local stack capture is
  79  `/private/tmp/lidpilot-rc6-uninstrumented-hidden-app.sample.txt`.
  80
  81  The fixed live `pmset` reads remain the largest single component (50.6% of this
  82  run). Even eliminating all app CPU would leave approximately **0.4745%** at the
  83  measured helper/child costs. This is a conditional subtraction, not a universal
  84  lower bound or an achievable measurement. A UI-only change cannot be presented
  85  as evidence that the current run would meet the gate.
  86
  87  No additional runtime optimization has been selected from this baseline.
  88  The prior live-read equivalence investigation, mandatory independent reads,
  89  watchdog timing, leases, fences, conflict and unknown-state handling remain
  90  unchanged. No speculative RC is justified merely by removing instrumentation.
```


<a id="s4"></a>
## S4 — Trace completeness condition

File: `evidence/scripts/analyze-performance-profile.py`
SHA-256: `f31291b83215a51f3b4d2ff19ac46ba7293ce6a8cfb1cfa4e1da11c0d45ad6f3`

Original lines 55–85:
```text
  55      beginnings = {e['span_id']: e for e in events if e['event'] == 'pmset_span_begin'}
  56      endings = {e['span_id']: e for e in events if e['event'] == 'pmset_span_end'}
  57      boundary = [sid for sid in beginnings.keys() & endings.keys()
  58                  if (start <= beginnings[sid]['wall_time'] <= end) != (start <= endings[sid]['wall_time'] <= end)]
  59      unmatched = [e['span_id'] for e in window if e['event'] in ('pmset_span_begin', 'pmset_span_end')
  60                   and e['span_id'] not in beginnings.keys() & endings.keys()]
  61      for row in paths.values():
  62          row['calls_per_minute'] = row['calls'] * 60 / duration
  63          row['child_cpu_percent_of_one_core'] = (row['child_user_us'] + row['child_system_us']) / 1e6 / duration * 100
  64      factor = measurement['machTimebaseNumerator'] / measurement['machTimebaseDenominator'] / 1e9 / duration * 100
  65      split = {}
  66      for target in measurement['cpuByTarget']:
  67          pid = target['pid']
  68          if pid not in (app_pid, helper_pid):
  69              raise ValueError('Unexpected CPU measurement PID')
  70          role = 'app' if pid == app_pid else 'helper'
  71          split[role] = (target['ownUserTicks'] + target['ownSystemTicks']) * factor
  72          split[role + '_reaped_children'] = (target['reapedChildUserTicks'] + target['reapedChildSystemTicks']) * factor
  73      if len(split) != 4:
  74          raise ValueError('Both app and helper CPU measurements are required')
  75      if not math.isclose(sum(split.values()), measurement['cpuPercentOfOneCoreIncludingReapedChildren'], rel_tol=1e-9, abs_tol=1e-12):
  76          raise ValueError('CPU breakdown does not match aggregate measurement')
  77      return {'duration_seconds': duration, 'cpu_percent_of_one_core': split,
  78              'total_cpu_percent': measurement['cpuPercentOfOneCoreIncludingReapedChildren'],
  79              'event_origins': dict(origins), 'event_counts': dict(counts), 'events_per_minute': {k: v * 60 / duration for k, v in counts.items()},
  80              'pmset_by_path': dict(paths), 'sequence_gaps': gaps,
  81              'counts_complete': not gaps and not unmatched, 'boundary_spans': boundary, 'unmatched_spans': unmatched,
  82              'limitations': ['Profiling instrumentation overhead is included.',
  83                             'Commands crossing the window boundary need manual reconciliation.',
  84                             'No events before/after the measurement window must be checked against capture start/end.',
  85                             'Child command CPU is a separate getrusage measurement; compare it with recorder child counters.']}
```


<a id="s5"></a>
## S5 — Helper read placement

File: `installed-rc6-source/Runtime/HelperEngine.swift`
SHA-256: `5649586589b608cacd6def178cdea332de7cf32c1759b1765eacb52ade4a28ce`

Original lines 59–80:
```text
  59      private func handleFenced(_ request: WireRequest, client: UUID) -> WireReply {
  60          bootstrap()
  61          // Admission never queues a second client request ahead of this check.
  62          watchdogFenced()
  63          do {
  64              try request.validate()
  65              if request.operation == .inspect { return reply(success: !recoveryPending) }
  66              let previous = lastGeneration[client] ?? 0
  67              guard request.generation >= previous else { throw failure("Stale request rejected.") }
  68              // Keep this bounded even when multiple signed app instances reconnect.
  69              guard lastGeneration[client] != nil || lastGeneration.count < 64 else {
  70                  throw failure("Too many helper connections; retry after recovery.")
  71              }
  72              switch request.operation {
  73              case .inspect: break
  74              case .acquire:
  75                  guard request.generation > previous else { throw failure("Replayed activation rejected.") }
  76                  lastGeneration[client] = request.generation
  77                  try acquire(request, client: client)
  78              case .renew:
  79                  try renew(request, client: client)
  80              case .release:
```

Original lines 130–148:
```text
 130      private func watchdogFenced() {
 131          if recoveryPending, owns {
 132              do { try restore() } catch { lastMessage = error.localizedDescription }
 133              return
 134          }
 135          guard let current = lease else { return }
 136          do {
 137              let flag = try readObserved("watchdog")
 138              let snapshot = sampler.sample(flag: flag)
 139              let now = clock.now()
 140              if now.continuousSeconds >= current.expires || current.deadline.isExpired(at: now) ||
 141                  current.policy.evaluate(snapshot: snapshot, mode: current.mode, clock: now) != nil || flag != .on {
 142                  try restore()
 143                  lastMessage = "Session ended by the helper safety watchdog."
 144              }
 145          } catch {
 146              // Loss of observability is a stop condition, not permission to extend the lease.
 147              do { try restore() } catch { lastMessage = error.localizedDescription }
 148          }
```

Original lines 240–285:
```text
 240      private func renew(_ request: WireRequest, client: UUID) throws {
 241          guard let current = lease, current.client == client, current.session == request.sessionID,
 242                current.generation == request.generation, request.deadline == current.deadline,
 243                request.policy == current.policy, request.mode == current.mode else {
 244              throw failure("Lease identity or immutable session parameters do not match.")
 245          }
 246          guard lease != nil else { throw failure("The lease expired or safety requires a new session.") }
 247          let now = clock.now()
 248          guard now.continuousSeconds < current.expires, !current.deadline.isExpired(at: now) else {
 249              try restore()
 250              throw failure("The lease expired or safety requires a new session.")
 251          }
 252          lease?.expires = min(now.continuousSeconds + 60,
 253                               now.continuousSeconds + (current.deadline.remaining(at: now) ?? 60))
 254          #if LIDPILOT_PROFILE
 255          PerformanceTrace.event("lease_renew", fields: ["session_id": current.session.uuidString, "generation": String(current.generation)])
 256          #endif
 257          lastMessage = "Lease renewed and observed state verified."
 258      }
 259
 260      private func restore() throws {
 261          lease = nil
 262          guard owns else {
 263              if recoveryPending { throw failure("Recovery ownership is ambiguous; explicit recovery is required.") }
 264              lastMessage = "LidPilot has no owned override."
 265              return
 266          }
 267          recoveryPending = true
 268          // Even after a failed read, our durable intent gives authority to attempt restoration.
 269          try driver.setDisabled(false)
 270          guard try readObserved("restore_verify") == .off else { throw failure("Normal sleep policy could not be verified.") }
 271          try journal.clear()
 272          journalHealthy = true
 273          owns = false
 274          recoveryPending = false
 275          lastMessage = "LidPilot's sleep override is off and cleanup is verified."
 276      }
 277
 278      private func reply(success: Bool) -> WireReply {
 279          let flag = (try? readObserved("reply")) ?? .unknown
 280          return WireReply(helperBuild: build, flag: flag, ownsOverride: owns, recoveryPending: recoveryPending,
 281                           leaseActive: lease != nil, message: lastMessage,
 282                           success: success && flag != .unknown, sample: sampler.sample(flag: flag),
 283                           failureCode: success && flag != .unknown ? nil : (recoveryPending ? .recoveryRequired : .operationFailed),
 284                           health: HelperHealth(journalHealthy: journalHealthy, powerStateReadable: flag != .unknown,
 285                                                watchdogAvailable: true))
```


<a id="s6"></a>
## S6 — Tests that protect reply-time drift observation

File: `installed-rc6-source/Tests/HelperEngineTests.swift`
SHA-256: `aa1e40ecc31d0a5e79239c9e9e2d29bdae54195deaec656027b3278c1dcbe738`

Original lines 74–104:
```text
  74      @Test func renewalUsesOnePreflightWatchdogAndKeepsReplyReadback() throws {
  75          let platform = TestPlatform(); let engine = platform.engine(); let client = UUID()
  76          var request = try platform.acquire()
  77          #expect(engine.handle(request, client: client).success)
  78
  79          platform.readCount = 0
  80          request.operation = .renew
  81          let reply = engine.handle(request, client: client)
  82
  83          #expect(reply.success && reply.flag == .on)
  84          #expect(platform.readCount == 2) // Pre-dispatch watchdog plus live reply read-back.
  85      }
  86
  87      @Test func renewalReplyReadbackAndWatchdogHandleFlagDrift() throws {
  88          let platform = TestPlatform(); let engine = platform.engine(); let client = UUID()
  89          var request = try platform.acquire()
  90          #expect(engine.handle(request, client: client).success)
  91
  92          platform.readCount = 0
  93          platform.flagTurnsOffOnRead = 2
  94          request.operation = .renew
  95          let reply = engine.handle(request, client: client)
  96          #expect(reply.flag == .off)
  97
  98          platform.flagTurnsOffOnRead = nil
  99          engine.watchdog()
 100          let status = engine.handle(WireRequest(operation: .inspect, sessionID: UUID(), generation: 1), client: client)
 101          #expect(status.flag == .off && !status.leaseActive && !status.ownsOverride)
 102      }
 103
 104      @Test func renewalCannotExtendLeaseThatExpiresAfterPreflight() throws {
```


<a id="s7"></a>
## S7 — Helper scheduling and request serialization

File: `installed-rc6-source/Runtime/HelperService.swift`
SHA-256: `af97d6576831779c97c8fb3d117bada81ebe0881c92eaf92f8f17024ca5632c7`

Original lines 19–55:
```text
  19  /// Commands and recovery share a serial executor and an inherited process fence.
  20  public final class HelperService: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
  21      private let queue = DispatchQueue(label: "com.lidpilot.helper.state", qos: .utility)
  22      private let lock = NSLock()
  23      private let admission = HelperAdmission()
  24      private var watchdogQueued = false
  25      private var clients = 0
  26      private let engine: HelperEngine
  27      private let peerRequirement: String
  28      private var watchdog: DispatchSourceTimer?
  29
  30      public init(engine: HelperEngine, team: String) throws {
  31          self.engine = engine
  32          peerRequirement = try HelperIdentity.requirement(identifier: HelperIdentity.appID, team: team)
  33          super.init()
  34      }
  35
  36      public func startWatchdog() {
  37          let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
  38          timer.schedule(deadline: .now(), repeating: 10, leeway: .milliseconds(100))
  39          timer.setEventHandler { [weak self] in
  40              guard let self else { return }
  41              #if LIDPILOT_PROFILE
  42              PerformanceTrace.event("watchdog", fields: ["stage": "fire"])
  43              #endif
  44              self.lock.lock()
  45              guard !self.watchdogQueued else { self.lock.unlock(); return }
  46              self.watchdogQueued = true
  47              self.lock.unlock()
  48              self.queue.async {
  49                  self.engine.watchdog()
  50                  self.lock.lock(); self.watchdogQueued = false; self.lock.unlock()
  51              }
  52          }
  53          watchdog = timer
  54          timer.resume()
  55      }
```

Original lines 82–110:
```text
  82
  83      fileprivate func submit(_ payload: Data, endpoint: HelperEndpoint, reply: @escaping @Sendable (Data) -> Void) {
  84          guard admission.begin() else {
  85              reject(.busy, "The helper is checking power state; retry shortly.", reply: reply)
  86              return
  87          }
  88          queue.async {
  89              defer { self.admission.end() }
  90              var uid: uid_t = 0
  91              var gid: gid_t = 0
  92              _ = SCDynamicStoreCopyConsoleUser(nil, &uid, &gid)
  93              guard endpoint.isOpen, uid == endpoint.userID else {
  94                  self.reject(.unauthorized, "The active login session changed.", reply: reply)
  95                  return
  96              }
  97              guard let request = try? WireRequest.decode(payload) else {
  98                  self.reject(.invalidRequest, "The request is invalid or unsupported.", reply: reply)
  99                  return
 100              }
 101              #if LIDPILOT_PROFILE
 102              PerformanceTrace.event("xpc", fields: ["direction": "receive", "op": request.operation.rawValue, "session_id": request.sessionID.uuidString])
 103              #endif
 104              let result = self.engine.handle(request, client: endpoint.id)
 105              reply((try? result.encoded()) ?? Data())
 106          }
 107      }
 108
 109      fileprivate func reject(_ code: WireFailureCode, _ message: String,
 110                              reply: @escaping @Sendable (Data) -> Void) {
```


<a id="s8"></a>
## S8 — Coordinator observation/publication path

File: `installed-rc6-source/Runtime/SessionController.swift`
SHA-256: `851c1b6891cf5f5e3442f1e663ccbe69c076c0ea295666e3d871f727c41a9d57`

Original lines 151–205:
```text
 151      public func reconcile() async {
 152          #if LIDPILOT_PROFILE
 153          PerformanceTrace.event("reconcile", fields: ["stage": "begin", "phase": String(describing: phase), "already_reconciling": String(reconciling)])
 154          defer { PerformanceTrace.event("reconcile", fields: ["stage": "end", "phase": String(describing: phase)]) }
 155          #endif
 156          guard !reconciling, let mode = requestedMode, let deadline,
 157                phase == .active || phase == .starting else { return }
 158          reconciling = true
 159          defer { reconciling = false }
 160          let token = generation
 161          let snapshot = sampler.sample(flag: helperState?.flag ?? .unknown)
 162          observation = snapshot
 163          if deadline.isExpired(at: clock.now()) {
 164              await stop(reason: "Your session has ended.")
 165              return
 166          }
 167          if let reason = policy.evaluate(snapshot: snapshot, mode: mode, clock: clock.now()) {
 168              await stop(reason: Self.explanation(reason), safety: true)
 169              return
 170          }
 171          guard phase == .active else { return }
 172          // Drop a Smart display hold immediately on close, before a potentially delayed XPC reply.
 173          if mode == .smart, snapshot.lid != .open {
 174              do { assertions = try power.apply(system: true, display: false, timeout: min(60, deadline.remaining(at: clock.now()) ?? 60)) }
 175              catch { await stop(reason: error.localizedDescription, safety: true); return }
 176          }
 177          var reconcileError: (any Error)?
 178          await enqueue { [self] in
 179              guard token == generation else { return }
 180              do {
 181                  if mode.needsHelper {
 182                      let response = try await helper.send(WireRequest(operation: .renew, sessionID: sessionID, generation: token,
 183                                                                       deadline: deadline, policy: policy, mode: mode))
 184                      guard token == generation else { return }
 185                      helperState = response
 186                      guard response.success, response.leaseActive, response.ownsOverride, response.flag == .on, !response.recoveryPending else {
 187                          throw RuntimeFailure.unavailable(response.message)
 188                      }
 189                  }
 190                  guard token == generation else { return }
 191                  let current = sampler.sample(flag: helperState?.flag ?? .unknown)
 192                  guard !deadline.isExpired(at: clock.now()) else { throw RuntimeFailure.unavailable("Your session has ended.") }
 193                  if let reason = policy.evaluate(snapshot: current, mode: mode, clock: clock.now()) {
 194                      throw RuntimeFailure.unavailable(Self.explanation(reason))
 195                  }
 196                  observation = current
 197                  assertions = try power.apply(system: true, display: Self.displayHeld(mode, lid: current.lid),
 198                                               timeout: min(60, deadline.remaining(at: clock.now()) ?? 60))
 199                  message = Self.activeMessage(mode, lid: current.lid)
 200              } catch { reconcileError = error }
 201          }
 202          if let reconcileError, token == generation {
 203              await stop(reason: reconcileError.localizedDescription, safety: true)
 204          }
 205      }
```


<a id="s9"></a>
## S9 — Heartbeat schedule

File: `installed-rc6-source/App/AppModel.swift`
SHA-256: `7194e73f15700a997dc7f1db5bf7613c7c563c016f165487521b73fa8c9f8684`

Original lines 168–196:
```text
 168      private func sessionChanged(_ phase: SessionPhase, _ message: String) {
 169          diagnostics.record(phase, message)
 170          if controller.hasSession {
 171              if heartbeat == nil {
 172                  heartbeatGeneration += 1
 173                  let heartbeatToken = heartbeatGeneration
 174                  heartbeat = Task { [weak self] in
 175                      while let self, self.controller.hasSession, !Task.isCancelled {
 176                          let delay = max(0.1, min(15, self.controller.remaining ?? 15))
 177                          do { try await Task.sleep(for: .seconds(delay)) } catch { break }
 178                          #if LIDPILOT_PROFILE
 179                          PerformanceTrace.event("heartbeat", fields: ["stage": "fire", "delay_s": String(delay), "phase": String(describing: self.controller.phase)])
 180                          PerformanceTrace.event("reconcile_trigger", fields: ["source": "heartbeat", "phase": String(describing: self.controller.phase)])
 181                          #endif
 182                          await self.controller.reconcile()
 183                      }
 184                      if self?.heartbeatGeneration == heartbeatToken { self?.heartbeat = nil }
 185                  }
 186              }
 187          } else { heartbeatGeneration += 1; heartbeat?.cancel(); heartbeat = nil }
 188          if !isPreview, notify, phase == .paused || phase == .recovery || (phase == .off && message == "Your session has ended.") {
 189              let content = UNMutableNotificationContent()
 190              content.title = phase == .recovery ? "Cleanup needs attention" : (phase == .paused ? "LidPilot paused" : "Session finished")
 191              content.body = message
 192              let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
 193              Task { try? await UNUserNotificationCenter.current().add(request) }
 194          }
 195      }
 196  }
```


<a id="s10"></a>
## S10 — Hidden presentation and paused timeline

File: `installed-rc6-source/App/PilotPanel.swift`
SHA-256: `76032807f6ee78f9ce617606bb18e3285d81d1b7768ab39360fab7406e627772`

Original lines 1–53:
```text
   1  import SwiftUI
   2  import LidPilotCore
   3  import LidPilotRuntime
   4
   5  struct PilotPanel: View {
   6      @Bindable var model: AppModel
   7      @Environment(\.openWindow) private var openWindow
   8      @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
   9      @Environment(\.colorSchemeContrast) private var contrast
  10      @State private var visible = false
  11
  12      var body: some View {
  13          VStack(alignment: .leading, spacing: 16) {
  14              HStack(spacing: 10) {
  15                  PilotMark(size: 32)
  16                  Text("LidPilot").font(.system(size: 18, weight: .semibold))
  17                  Spacer()
  18                  HStack(spacing: 5) {
  19                      Circle().fill(model.controller.phase.color).frame(width: 5, height: 5)
  20                      Text(model.controller.phase.title).font(.system(size: 10, weight: .medium))
  21                  }
  22                  .padding(.horizontal, 9).padding(.vertical, 5)
  23                  .background(Color.primary.opacity(0.045), in: Capsule())
  24                  .accessibilityElement(children: .combine)
  25              }
  26              .padding(.bottom, 2)
  27
  28              if model.isPreview {
  29                  Label("Preview · power controls are simulated", systemImage: "testtube.2")
  30                      .font(.system(size: 10)).foregroundStyle(.secondary)
  31              }
  32
  33              VStack(spacing: 8) {
  34                  ForEach(Mode.allCases, id: \.self) { mode in
  35                      modeCard(mode)
  36                  }
  37              }
  38              .disabled(model.controller.updateBarrier || model.controller.phase == .stopping)
  39
  40              VStack(alignment: .leading, spacing: 10) {
  41                  HStack {
  42                      Text("SESSION").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
  43                      Spacer()
  44                      if model.controller.hasSession {
  45                          TimelineView(.animation(minimumInterval: 1, paused: !visible)) { _ in
  46                              #if LIDPILOT_PROFILE
  47                              let _ = PerformanceTrace.event("ui_timeline_render", fields: ["visible": String(visible)])
  48                              #endif
  49                              Text(remainingText).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
  50                          }
  51                      } else {
  52                          Text(model.duration.title).font(.subheadline).foregroundStyle(.secondary)
  53                      }
```

Original lines 145–157:
```text
 145              else {
 146                  Rectangle().fill(.regularMaterial)
 147                      .overlay(Color(nsColor: .windowBackgroundColor).opacity(0.45))
 148              }
 149          }
 150          .onAppear {
 151              visible = true
 152              if !model.onboardingComplete && !model.isPreview { model.showOnboarding = true }
 153          }
 154          .onDisappear { visible = false }
 155          .onChange(of: model.showOnboarding) { _, value in
 156              if value { openWindow(id: "welcome"); model.showOnboarding = false; NSApp.activate(ignoringOtherApps: true) }
 157          }
```


<a id="s11"></a>
## S11 — Window ownership

File: `installed-rc6-source/App/LidPilotApp.swift`
SHA-256: `445ee1e0404451a10e1afc6a7ae3b96e9399a324cf1cd3477f6fbff4c5c4fb9a`

Original lines 6–46:
```text
   6  @main struct LidPilotApp: App {
   7      @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
   8      @State private var model: AppModel
   9      init() {
  10          let model = AppModel()
  11          _model = State(initialValue: model)
  12          delegate.model = model
  13      }
  14      var body: some Scene {
  15          MenuBarExtra {
  16              PilotPanel(model: model)
  17                  .onAppear { delegate.model = model; model.refreshHelper() }
  18          } label: {
  19              Image(systemName: model.controller.hasSession ? "laptopcomputer.and.arrow.down" : "laptopcomputer")
  20                  .accessibilityLabel("LidPilot, \(model.controller.phase.rawValue)")
  21          }
  22          .menuBarExtraStyle(.window)
  23
  24          #if DEBUG
  25          Window("LidPilot · UI Preview", id: "ui-preview") {
  26              if model.isPreview { PilotPanel(model: model).onAppear { delegate.model = model } }
  27          }
  28          .defaultLaunchBehavior(model.isPreview ? .presented : .suppressed)
  29          .windowResizability(.contentSize)
  30          .defaultPosition(.center)
  31          #endif
  32
  33          Window("LidPilot Settings", id: "settings") {
  34              SettingsView(model: model).onAppear { delegate.model = model; model.refreshHelper() }
  35          }
  36          .defaultLaunchBehavior(.suppressed)
  37          .defaultSize(width: 640, height: 520)
  38          .windowResizability(.contentSize)
  39
  40          Window("Welcome to LidPilot", id: "welcome") {
  41              WelcomeView(model: model).onAppear { delegate.model = model }
  42          }
  43          .windowResizability(.contentSize)
  44          .defaultLaunchBehavior(.suppressed)
  45          .defaultSize(width: 520, height: 440)
  46      }
```


<a id="s12"></a>
## S12 — Uncancelled completed-request timeout

File: `installed-rc6-source/Runtime/HelperTransport.swift`
SHA-256: `11df723f0fda561c795c6d0f6cc7a101bbbc427deeeb25a3d641cce283c9ee8a`

Original lines 47–57:
```text
  47  private final class ReplyOnce: @unchecked Sendable {
  48      private let lock = NSLock()
  49      private var continuation: CheckedContinuation<Data, any Error>?
  50      init(_ continuation: CheckedContinuation<Data, any Error>) { self.continuation = continuation }
  51      func finish(_ result: Result<Data, any Error>) {
  52          lock.lock()
  53          let waiting = continuation
  54          continuation = nil
  55          lock.unlock()
  56          waiting?.resume(with: result)
  57      }
```

Original lines 72–118:
```text
  72      public func send(_ request: WireRequest) async throws -> WireReply {
  73          #if LIDPILOT_PROFILE
  74          PerformanceTrace.event("xpc", fields: ["direction": "send", "op": request.operation.rawValue, "session_id": request.sessionID.uuidString])
  75          defer { PerformanceTrace.event("xpc", fields: ["direction": "complete", "op": request.operation.rawValue]) }
  76          #endif
  77          let activates = request.operation == .acquire || request.operation == .renew
  78          if activates, verifiedBuild != build {
  79              let status = try await send(WireRequest(operation: .inspect, sessionID: request.sessionID, generation: request.generation))
  80              guard status.helperBuild == build else {
  81                  throw RuntimeFailure.unavailable("The installed helper needs repair for this app version.")
  82              }
  83          }
  84          let payload = try request.encoded()
  85          let channel: NSXPCConnection
  86          if let connection { channel = connection } else {
  87              let requirement = try HelperIdentity.requirement(identifier: HelperIdentity.helperID, team: HelperIdentity.ownTeam())
  88              channel = NSXPCConnection(machServiceName: HelperIdentity.helperID, options: .privileged)
  89              channel.setCodeSigningRequirement(requirement)
  90              channel.remoteObjectInterface = NSXPCInterface(with: HelperXPCProtocol.self)
  91              channel.activate()
  92              connection = channel
  93          }
  94          do {
  95              let data: Data = try await withCheckedThrowingContinuation { continuation in
  96                  let once = ReplyOnce(continuation)
  97                  let proxy = channel.remoteObjectProxyWithErrorHandler { error in once.finish(.failure(error)) }
  98                  guard let endpoint = proxy as? HelperXPCProtocol else {
  99                      once.finish(.failure(RuntimeFailure.unavailable("The helper interface is unavailable.")))
 100                      return
 101                  }
 102                  endpoint.exchange(payload) { once.finish(.success($0)) }
 103                  DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30) {
 104                      once.finish(.failure(RuntimeFailure.unavailable("The helper did not reply in time.")))
 105                  }
 106              }
 107              let reply = try WireReply.decode(data)
 108              verifiedBuild = reply.helperBuild
 109              // Compatible old helpers must remain reachable for inspection and safe cleanup.
 110              guard !activates || reply.helperBuild == build else {
 111                  throw RuntimeFailure.unavailable("The installed helper needs to be replaced for this app version.")
 112              }
 113              return reply
 114          } catch {
 115              disconnect()
 116              throw error
 117          }
 118      }
```


<a id="s13"></a>
## S13 — Command runner EOF/HUP control flow

File: `installed-rc6-source/Runtime/PMSetDriver.swift`
SHA-256: `5a5403e076052675224d4aff70668f7012444a7f0a95923a0481bdd9934a175f`

Original lines 38–73:
```text
  38          runner = POSIXCommandRunner(executable: "/usr/bin/pmset")
  39      }
  40
  41      // Internal-only seam for bounded tests. Production construction keeps the
  42      // executable and arguments fixed to pmset below.
  43      internal init(fence: CommandFence, runner: POSIXCommandRunner) {
  44          self.fence = fence
  45          self.runner = runner
  46      }
  47
  48      public func read() throws -> FlagState {
  49          Self.parse(try run(arguments: ["-g"]))
  50      }
  51
  52      public func setDisabled(_ disabled: Bool) throws {
  53          guard geteuid() == 0 else { throw RuntimeFailure.unavailable("The approved helper is required.") }
  54          guard fence?.descriptorForCurrentBody() != nil else {
  55              throw RuntimeFailure.unavailable("A trusted command fence is required.")
  56          }
  57          _ = try run(arguments: ["-a", "disablesleep", disabled ? "1" : "0"])
  58      }
  59
  60      public func withMutationFence<T>(_ operation: () throws -> T) throws -> T {
  61          guard let fence else {
  62              throw RuntimeFailure.unavailable("The approved helper is required for mutations.")
  63          }
  64          return try fence.withExclusive { try operation() }
  65      }
  66
  67      public static func parse(_ output: String) -> FlagState {
  68          let values = output.split(separator: "\n").compactMap { line -> String? in
  69              let fields = line.split(whereSeparator: \.isWhitespace)
  70              guard fields.first == "SleepDisabled", fields.count == 2 else { return nil }
  71              return String(fields[1])
  72          }
  73          guard values.count == 1 else { return .unknown }
```

Original lines 153–214:
```text
 153      internal func run(arguments: [String], inheritedFence: Int32?) throws -> String {
 154          let child = try spawn(arguments: arguments, inheritedFence: inheritedFence)
 155          #if LIDPILOT_PROFILE
 156          PerformanceTrace.event("spawn", fields: ["child_pid": String(child.pid), "callsite": PerformanceTrace.currentCallsite, "span_id": PerformanceTrace.currentSpanID ?? "none"])
 157          #endif
 158          defer { close(child.outputDescriptor) }
 159
 160          var output = Data()
 161          var outputTooLarge = false
 162          var status: Int32 = 0
 163          let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(timeout * 1_000_000_000)
 164          var childReaped = false
 165
 166          do {
 167              while true {
 168                  let waited = waitpid(child.pid, &status, WNOHANG)
 169                  if waited == child.pid {
 170                      childReaped = true
 171                      if try drain(child.outputDescriptor, into: &output, tooLarge: &outputTooLarge) {
 172                          break
 173                      }
 174                      try finishDrain(child.outputDescriptor, into: &output, tooLarge: &outputTooLarge)
 175                      break
 176                  }
 177                  if waited < 0 {
 178                      if errno == EINTR { continue }
 179                      if errno == ECHILD {
 180                          childReaped = true // It is no longer ours; never signal a possibly reused PID.
 181                          throw POSIXCommandError.io("waitpid lost child")
 182                      }
 183                      throw POSIXCommandError.io("waitpid errno \(errno)")
 184                  }
 185
 186                  _ = try drain(child.outputDescriptor, into: &output, tooLarge: &outputTooLarge)
 187                  if DispatchTime.now().uptimeNanoseconds >= deadline {
 188                      throw POSIXCommandError.timedOut(childReaped: false)
 189                  }
 190                  let waitMilliseconds = millisecondsUntil(deadline: deadline, maximum: 20)
 191                  guard waitMilliseconds > 0 else {
 192                      throw POSIXCommandError.timedOut(childReaped: false)
 193                  }
 194                  _ = try waitForOutput(child.outputDescriptor, milliseconds: waitMilliseconds)
 195              }
 196
 197              if outputTooLarge { throw POSIXCommandError.outputTooLarge }
 198              guard status == 0 else { throw POSIXCommandError.failed(status) }
 199              return String(decoding: output, as: UTF8.self)
 200          } catch let error as POSIXCommandError {
 201              guard !childReaped else { throw error }
 202              let reaped = terminateAndReap(child, status: &status,
 203                                            output: &output, tooLarge: &outputTooLarge)
 204              guard reaped else { throw POSIXCommandError.childNotReaped(error.message) }
 205              if case .timedOut = error { throw POSIXCommandError.timedOut(childReaped: true) }
 206              throw error
 207          } catch {
 208              guard !childReaped else { throw error }
 209              let reaped = terminateAndReap(child, status: &status,
 210                                            output: &output, tooLarge: &outputTooLarge)
 211              guard reaped else { throw POSIXCommandError.childNotReaped(error.localizedDescription) }
 212              throw error
 213          }
 214      }
```

Original lines 329–405:
```text
 329                  if errno == ECHILD { return true }
 330                  return false
 331              }
 332              _ = try? drain(child.outputDescriptor, into: &output, tooLarge: &tooLarge)
 333              let waitMilliseconds = millisecondsUntil(deadline: deadline, maximum: 10)
 334              if waitMilliseconds > 0 {
 335                  _ = try? waitForOutput(child.outputDescriptor, milliseconds: waitMilliseconds)
 336              }
 337              if killFailed { Thread.sleep(forTimeInterval: 0.001) }
 338          }
 339          return false
 340      }
 341
 342      private func drain(_ descriptor: Int32, into output: inout Data,
 343                         tooLarge: inout Bool) throws -> Bool {
 344          var buffer = [UInt8](repeating: 0, count: 4_096)
 345          for _ in 0..<16 {
 346              let count = buffer.withUnsafeMutableBytes { bytes -> Int in
 347                  guard let baseAddress = bytes.baseAddress else { return 0 }
 348                  return Darwin.read(descriptor, baseAddress, bytes.count)
 349              }
 350              if count > 0 {
 351                  let remaining = max(0, Self.maxOutputBytes - output.count)
 352                  if remaining > 0 { output.append(contentsOf: buffer.prefix(min(count, remaining))) }
 353                  if count > remaining { tooLarge = true }
 354                  continue
 355              }
 356              if count == 0 { return true }
 357              if errno == EINTR { continue }
 358              if errno == EAGAIN || errno == EWOULDBLOCK { return false }
 359              throw POSIXCommandError.io("read errno \(errno)")
 360          }
 361          return false
 362      }
 363
 364      private func finishDrain(_ descriptor: Int32, into output: inout Data,
 365                               tooLarge: inout Bool) throws {
 366          let deadline = DispatchTime.now().uptimeNanoseconds +
 367              UInt64(Self.finalDrainSeconds * 1_000_000_000)
 368          while DispatchTime.now().uptimeNanoseconds < deadline {
 369              if try drain(descriptor, into: &output, tooLarge: &tooLarge) { return }
 370              let waitMilliseconds = millisecondsUntil(deadline: deadline, maximum: 10)
 371              guard waitMilliseconds > 0 else { return }
 372              let hungUp = try waitForOutput(descriptor, milliseconds: waitMilliseconds)
 373              if hungUp { Thread.sleep(forTimeInterval: 0.005) }
 374          }
 375      }
 376
 377      private func millisecondsUntil(deadline: UInt64, maximum: Int32) -> Int32 {
 378          let now = DispatchTime.now().uptimeNanoseconds
 379          guard now < deadline else { return 0 }
 380          let remaining = deadline - now
 381          let requested = min(remaining, UInt64(maximum) * 1_000_000)
 382          return max(1, Int32((requested + 999_999) / 1_000_000))
 383      }
 384
 385      private func waitForOutput(_ descriptor: Int32, milliseconds: Int32) throws -> Bool {
 386          var descriptorEvents = pollfd(fd: descriptor,
 387                                        events: Int16(POLLIN | POLLHUP | POLLERR),
 388                                        revents: 0)
 389          let result = Darwin.poll(&descriptorEvents, 1, milliseconds)
 390          guard result >= 0 || errno == EINTR else {
 391              throw POSIXCommandError.io("poll errno \(errno)")
 392          }
 393          return result > 0 && descriptorEvents.revents & Int16(POLLHUP) != 0
 394      }
 395
 396      private func setCloseOnExec(_ descriptor: Int32) throws {
 397          let flags = fcntl(descriptor, F_GETFD)
 398          guard flags >= 0, fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) >= 0 else {
 399              throw POSIXCommandError.spawn("fcntl errno \(errno)")
 400          }
 401      }
 402
 403      private func setNonBlocking(_ descriptor: Int32) throws {
 404          let flags = fcntl(descriptor, F_GETFL)
 405          guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) >= 0 else {
```


<a id="s14"></a>
## S14 — Assertion maintenance

File: `installed-rc6-source/Runtime/PowerAssertions.swift`
SHA-256: `ba5ad020e10ba45d26aee126b29c7aa2c50c16bce6c4b1b231cca69c06c62fc9`

Original lines 39–92:
```text
  39      public func apply(system: Bool, display: Bool, timeout: Double) throws -> AssertionState {
  40          guard timeout.isFinite, timeout > 0, timeout <= 60 else {
  41              throw RuntimeFailure.unavailable("Invalid assertion lease duration.")
  42          }
  43          // On lid close, drop the display assertion before doing any other work.
  44          if !display { try remove(&displayID) }
  45          if !system { try remove(&systemID) }
  46          if system { try maintain(&systemID, type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString, timeout: timeout) }
  47          if display { try maintain(&displayID, type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString, timeout: timeout) }
  48          let state = observed()
  49          guard state.system == (system ? .on : .off), state.display == (display ? .on : .off) else {
  50              throw RuntimeFailure.unavailable("LidPilot's assertions could not be verified.")
  51          }
  52          return state
  53      }
  54
  55      public func release() throws -> AssertionState {
  56          // Attempt both releases even if the first fails.
  57          var failure: (any Error)?
  58          do { try remove(&displayID) } catch { failure = error }
  59          do { try remove(&systemID) } catch { failure = error }
  60          if let failure { throw failure }
  61          return observed()
  62      }
  63
  64      public func observed() -> AssertionState {
  65          AssertionState(system: level(systemID), display: level(displayID))
  66      }
  67
  68      public func sleep() throws {
  69          guard observed() == .off else { throw RuntimeFailure.unavailable("Release LidPilot's assertions before sleeping.") }
  70          let connection = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
  71          guard connection != 0 else { throw RuntimeFailure.unavailable("macOS sleep service is unavailable.") }
  72          defer { IOServiceClose(connection) }
  73          guard IOPMSleepSystem(connection) == kIOReturnSuccess else {
  74              throw RuntimeFailure.unavailable("macOS did not accept the sleep request.")
  75          }
  76      }
  77
  78      private func maintain(_ id: inout IOPMAssertionID?, type: CFString, timeout: Double) throws {
  79          if let existing = id {
  80              guard level(existing) == .on,
  81                    IOPMAssertionSetProperty(existing, kIOPMAssertionTimeoutKey as CFString, timeout as CFNumber) == kIOReturnSuccess else {
  82                  throw RuntimeFailure.unavailable("An assertion expired or could not be renewed.")
  83              }
  84          } else {
  85              var newID: IOPMAssertionID = 0
  86              guard IOPMAssertionCreateWithDescription(type, "LidPilot session" as CFString,
  87                      "User-requested, time-limited keep-awake session" as CFString, nil, nil,
  88                      timeout, kIOPMAssertionTimeoutActionRelease as CFString, &newID) == kIOReturnSuccess else {
  89                  throw RuntimeFailure.unavailable("macOS could not create the keep-awake assertion.")
  90              }
  91              id = newID
  92          }
```

Original lines 110–116:
```text
 110      private func level(_ id: IOPMAssertionID?) -> FlagState {
 111          guard let id else { return .off }
 112          guard let properties = IOPMAssertionCopyProperties(id)?.takeRetainedValue() as? [String: Any],
 113                let value = properties[kIOPMAssertionLevelKey] as? NSNumber else { return .unknown }
 114          return value.intValue == kIOPMAssertionLevelOn ? .on : .off
 115      }
 116  }
```


<a id="s15"></a>
## S15 — Repeated native system sampling

File: `installed-rc6-source/Runtime/SystemState.swift`
SHA-256: `3a57d60e17c421ab39544446d8390bddd182a196e4134b041e46b63f23326740`

Original lines 9–95:
```text
   9      func now() -> ClockSample
  10  }
  11
  12  public struct SystemClock: RuntimeClock {
  13      private let bootID: String
  14      private let secondsPerTick: Double
  15
  16      public init() {
  17          var size = 0
  18          sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0)
  19          var bytes = [CChar](repeating: 0, count: max(size, 1))
  20          if sysctlbyname("kern.bootsessionuuid", &bytes, &size, nil, 0) == 0 {
  21              bootID = String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
  22          } else {
  23              // An unavailable boot identity must not make persisted deadlines reusable.
  24              bootID = UUID().uuidString
  25          }
  26          var info = mach_timebase_info_data_t()
  27          mach_timebase_info(&info)
  28          secondsPerTick = Double(info.numer) / Double(info.denom) / 1_000_000_000
  29      }
  30
  31      public func now() -> ClockSample {
  32          ClockSample(continuousSeconds: Double(mach_continuous_time()) * secondsPerTick,
  33                      wallDate: Date(), bootID: bootID)
  34      }
  35  }
  36
  37  public protocol PowerSampling: Sendable {
  38      func sample(flag: FlagState) -> PowerSnapshot
  39  }
  40
  41  /// Only public observation APIs and documented IOPM registry keys. Never adjusts brightness.
  42  public struct SystemPowerSampler: PowerSampling {
  43      private let clock: any RuntimeClock
  44      public init(clock: any RuntimeClock = SystemClock()) { self.clock = clock }
  45
  46      public func sample(flag: FlagState = .unknown) -> PowerSnapshot {
  47          let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
  48          var lid: LidState = .unknown
  49          if root != 0 {
  50              if let value = IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString,
  51                                                            kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool {
  52                  lid = value ? .closed : .open
  53              }
  54              IOObjectRelease(root)
  55          }
  56
  57          var power: PowerSource = .unknown
  58          var battery: Int?
  59          if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
  60              if let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? {
  61                  if type == kIOPSACPowerValue { power = .external }
  62                  if type == kIOPSBatteryPowerValue { power = .battery }
  63              }
  64              if let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
  65                  for source in sources {
  66                      guard let value = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
  67                            value[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
  68                            let current = value[kIOPSCurrentCapacityKey] as? Int,
  69                            let maximum = value[kIOPSMaxCapacityKey] as? Int,
  70                            maximum > 0, current >= 0, current <= maximum else { continue }
  71                      battery = Int(Double(current) / Double(maximum) * 100)
  72                      break
  73                  }
  74              }
  75          }
  76
  77          let thermal: ThermalLevel
  78          switch ProcessInfo.processInfo.thermalState {
  79          case .nominal: thermal = .nominal
  80          case .fair: thermal = .fair
  81          case .serious: thermal = .serious
  82          case .critical: thermal = .critical
  83          @unknown default: thermal = .unknown
  84          }
  85          var count: UInt32 = 0
  86          var topology: Int?
  87          if CGGetOnlineDisplayList(0, nil, &count) == .success, count <= 64 {
  88              var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
  89              if CGGetOnlineDisplayList(count, &ids, &count) == .success {
  90                  topology = ids.prefix(Int(count)).filter { CGDisplayIsBuiltin($0) == 0 }.count
  91              }
  92          }
  93          return PowerSnapshot(sampledAt: clock.now(), lid: lid, power: power, batteryPercent: battery,
  94                               thermal: thermal, lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
  95                               externalDisplayCount: topology, sleepDisabled: flag)
```
