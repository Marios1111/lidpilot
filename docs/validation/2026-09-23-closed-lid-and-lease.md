# Closed-lid and lease validation — 2026-09-23

This record extends [the RC1 native validation](2026-09-21-native-and-release.md); it is not stable V1 approval. Tested app: installed, Developer ID signed/notarized LidPilot 1.0.0 (1), helper build 1, team `L69774LN97`. Source revision for the installed RC1 is `67a176b8b9b17be88d29d9225df2df61a4483b98`; the observer and lease probe are local validation tools and are not shipped in the app. Host: Apple M4 MacBook Air, macOS 27.2 (26B5086k), built-in display only, AC connected and charging, lid open before setup, one-minute macOS display-idle setting. The other controller's helper was present, but its override was independently read as off before LidPilot took ownership. The operator explicitly authorized and assisted with the physical test.

## G2: Keep Mac Running

The native menu panel started a one-hour Keep Mac Running session. Before closing, independent `pmset` read-back showed `SleepDisabled=1`, LidPilot's `PreventUserIdleSystemSleep` assertion present, and `PreventUserIdleDisplaySleep=0`. A harmless task appended a UTC and monotonic timestamp every second and sampled the lid sensor and sleep flag every five seconds.

The sensor reported closed for 50 consecutive samples, from 16:12:21.999 to 16:13:11.121 UTC. The observer recorded `SleepDisabled=1` throughout the complete 240-second run and a maximum timestamp gap of 1.0725 seconds, including closure. On reopening, the sensor reported open and the override remained owned until the separate recovery test below. The operator saw the built-in screen darken after about one minute and confirmed normal reopening. The macOS power log emitted a `Display is turned off` notification at 19:13:08 local, during the close/reopen transition; it also emitted `Display is turned on` at that instant. This is a visual report plus macOS display-policy evidence, not an electrical panel/backlight measurement or proof of immediate shutdown. No external display or dock was available; those topologies remain untested.

The ignored local raw trace is `release-private/validation/2026-09-23/keep-running-rc1.jsonl`, SHA-256 `d5d36241325a22f3eaf59e89590b8f2ebb1f5db087b6ab043b7e31c76292da04`.

## G3: independent helper lease expiry

With the lid independently read open and the same session still owned, a bounded local probe verified the exact installed GUI process path, sent `SIGSTOP` to that GUI only, sampled `pmset -g` once per second for 90 seconds, and resumed it in a `finally` block. The probe never wrote a power setting. The helper's 60-second lease and ten-second watchdog are implemented independently of the GUI.

The first sampled `SleepDisabled=0` occurred 65.018 seconds after suspension. The override stayed off in the final 20 post-resume samples; final sample was at 110.451 seconds. This establishes real helper cleanup on lease expiry and no re-acquisition during that post-resume window. **The installed RC1 GUI nevertheless entered Recovery required**, showing “An assertion could not be released.” Native Retry Cleanup did not clear it, and the native Quit action did not exit. The app was terminated only after independently verifying `SleepDisabled=0` and no LidPilot assertions; a subsequent launch began Off. This is a release-blocking GUI cleanup defect, not a successful end-to-end G3 result.

A bounded public-IOKit probe reproduced the mismatch: a one-second system assertion had no properties after expiry, but `IOPMAssertionRelease` returned `kIOReturnBadArgument` (`-536870206`), whereas RC1 accepted only success or `kIOReturnNotFound` (`-536870160`). The probe created no persistent assertion or `pmset` override. Corrected source must be rebuilt and the real lease-expiry path retested before this gate can pass. Helper-crash behavior and safely reproducible failed read-back/restore paths also remain open.

The ignored local raw report is `release-private/validation/2026-09-23/lease-expiry-rc1.json`, SHA-256 `714a698409da9fddce8458449461a57141ca50c34d800d09e82c0b9694fd6e07`.

## Performance: Keep Screen On, RC1

The operator ran the public `proc_pid_rusage` recorder with administrator access to the installed app (PID 85339) and helper (PID 540), the popover closed, the lid open, AC connected, and a one-hour Keep Screen On session settled. It ran from 16:30:54 UTC for 600.004 seconds with 121 samples. The recorder rejects process replacement and read failures. At completion, the system/display assertions remained present and `SleepDisabled=0`; this was not a helper-backed mode. Native Turn Off then showed Off, and independent read-back showed no LidPilot assertions and `SleepDisabled=0`. This RC1 measurement is useful evidence, but the corrected candidate still needs its own acceptance review.

| Metric | Result | Product target |
| --- | ---: | --- |
| Mean CPU, app/helper plus reaped children | 0.0793% of one core | PASS, ≤0.2% |
| Mean combined physical footprint | 37.316 MiB | PASS, ≤75 MiB |
| Maximum sampled combined physical footprint | 38.251 MiB | PASS, ≤75 MiB sampled |
| Interrupt wakeups | 0.4267/s | Recorded; no numeric threshold |
| Package-idle wakeups | 0.0783/s | Recorded; no numeric threshold |
| Reported process energy counter delta | 111,670,531 nJ | Accounting value, not Activity Monitor Energy Impact |

Raw report: `/private/tmp/lidpilot-keep-screen-on-rc1.json`, SHA-256 `895b061a79598d1e077de84157138a8ece624e87afcaa1626a6d36dfef45bc1d`. These are process counters, not whole-machine energy, and five-second footprint samples do not establish an absolute transient peak. Visible click-to-pending latency remains unmeasured.

## G4: signed wrong-console client

With the installed app Off, no LidPilot assertions and `SleepDisabled=0`, the operator ran the fixed inspect-only XPC probe as the existing `nobody` account. The probe's effective signature had identifier `com.lidpilot.app` and Team ID `L69774LN97`; the console user was `marios` (UID 501). Its output was `outcome=connection_interrupted; rejection_is_not_proven`, which is correctly inconclusive by itself. The concurrent macOS log explicitly recorded `Peer connection was rejected by the listener` for that probe PID. The helper listener checks the connection's effective UID against the current console UID before accepting a client, so the log plus signed identity and operator command support wrong-console rejection. No valid mutation request was sent, and the override remained off.

The filtered local log is `release-private/validation/2026-09-23/wrong-console-xpc.log`, SHA-256 `33494b83da6c47ab65bf9a0da3764625c7f0e625d65a0a57c401026688387687`. The separately named Apple Development identity on this Mac still produces the **same** effective Team ID when signing this probe; it cannot serve as a genuine wrong-team test. That G4 case remains untested.

## Corrected RC2: local candidate, pending live retest

Runtime fix `e2037dc` treats an expired assertion's `kIOReturnBadArgument` as clearable only when the immediate public-IOKit properties read-back is absent. Other release errors and still-present assertions remain failures. The focused tests (3), full Runtime suite (54), Core suite (21), Debug and optimized Release builds, and static release checks passed. [CI run 35891274636](https://github.com/Marios1111/lidpilot/actions/runs/35891274636) passed at the fix revision. None of these checks substitutes for rerunning the installed lease-expiry case.

The corrected arm64 app/helper build 2 was Developer ID signed. Apple accepted app submission `dcbb4234-11c7-446d-bc93-c69081414591` and DMG submission `c85fc2a9-cb78-4580-9e32-bc14d56ade4f`; both artifacts were stapled and validated. Gatekeeper accepted the app as a notarized Developer ID build. After the RC2 changelog was corrected, the unchanged notarized app/DMG were copied with metadata preserved into a fresh local stage, revalidated, and used to generate the final signed Sparkle archive, feed, and notes. The manifest hashes match every local file; a one-byte modified archive was rejected by signature verification. Private keys and credentials remained outside Git. This is local packaging evidence, not a published RC or a passed update lifecycle.

| Final local artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `LidPilot-1.0.0-rc.2.dmg` | 2,225,580 | `6483b00d409789405dbd03d0f413d695d433d5ff35e9e879a7cf8bf1c7352c9a` |
| `LidPilot-1.0.0-rc.2.zip` | 1,897,765 | `de5ead807c4de9f12cd3efb4c176d31ec3d6fb9273b3f4bd042b055ddbc81f56` |
| `appcast.xml` | 1,616 | `2337eb417a4421d3bb82b8132451f8cd7ead629263cadb5a1ffb5272eaa20233` |
| Signed RC2 notes | 4,264 | `a3a195bb4ea01e09d6665642d0ac8e4bcee0a5700119c44d5063ccaabb25cb0a` |

The final local manifest is SHA-256 `efcbd247974a2eb004d2d09398127c56b0de4eea9309f88c8689dd5b37402cf5`. It retains `hardwareValidation=pending`. The earlier notarized build-2 stage used obsolete notes and was not published.

## RC2 publication and hosted-byte verification

The reviewed source tag `v1.0.0-rc.2` points to `0116ef888f58bf92741fdbcc6b778b1d93ee7aac`. Its [CI run](https://github.com/Marios1111/lidpilot/actions/runs/35892178926) passed the Swift tests, release fixtures, Debug build and optimized Release build. The [RC2 GitHub prerelease](https://github.com/Marios1111/lidpilot/releases/tag/v1.0.0-rc.2) includes the final DMG, update ZIP, signed notes, signed appcast and manifest. Each of the five assets was downloaded through its anonymous public URL and compared byte-for-byte by SHA-256 with the final local stage; all matched the table and manifest above. The update archive URL is versioned and immutable within the signed feed.

The exact signed feed and notes bytes were committed at `146f3654b243b50b249f18332820cf999fe266fb`. The manual [Pages deployment](https://github.com/Marios1111/lidpilot/actions/runs/35892765712) and that commit's [CI run](https://github.com/Marios1111/lidpilot/actions/runs/35892757173) passed. Anonymous downloads from `https://marios1111.github.io/lidpilot/rc/appcast.xml` and its RC2 notes URL matched the signed local bytes with SHA-256 `2337eb417a4421d3bb82b8132451f8cd7ead629263cadb5a1ffb5272eaa20233` and `a3a195bb4ea01e09d6665642d0ac8e4bcee0a5700119c44d5063ccaabb25cb0a`, respectively. The installed update path is recorded below.

## Real signed RC1 to RC2 update

The installed RC1 was verified Off with `SleepDisabled=0` and no LidPilot assertions. Its manual Check for Updates fetched the hosted signed RC2 feed and notes, displayed build 2 against installed build 1, downloaded the signed ZIP, and reached Sparkle's “Ready to Install” state. Before the final install, independent read-back still showed the override off and no LidPilot assertions. “Install and Relaunch” replaced `/Applications/LidPilot.app`; the installed bundle then reported build 2, passed `codesign --verify --deep --strict`, and ran as a new GUI process. Its native panel began Off with the preserved preferred mode and duration. The new helper showed Approved in Settings; a Keep Mac Running session acquired `SleepDisabled=1` with its system assertion and no display assertion, proving that the replacement helper accepted the build-2 client. Native Turn Off restored `SleepDisabled=0` and removed the assertion. The final published RC2 DMG also passed `stapler validate` and Gatekeeper as `Notarized Developer ID`.

An **active-session RC1 update check exposed a new safety defect** before this upgrade: the app correctly rejected RC2 installation, but Sparkle presented a synchronous `NSAlert.runModal` error. While that alert remained open behind other app windows, the app's Swift-concurrency renewal task did not run; its 60-second assertions expired although the panel still said Session active. A read-only two-second stack sample captured Sparkle's update-abort path inside `NSAlert.runModal`. Once the alert was dismissed, RC1 entered its known expired-assertion Recovery error. The global override and LidPilot assertions were independently confirmed off before the RC1 GUI alone was restarted; it relaunched Off. This is not a passed active-session update-safety test. Fix `236a8dc` disables manual update actions during a session and rejects checks before Sparkle can present this modal path. Its Swift tests, Debug/Release builds, isolated native UI smoke, and [CI](https://github.com/Marios1111/lidpilot/actions/runs/35894500968) passed; a newer signed installed candidate must prove the behavior live.

## Corrected RC2 lease expiry and helper crash

With RC2 build 2's Keep Mac Running session owned, the same bounded probe suspended only the verified installed GUI for 90 seconds and resumed it in `finally`. The helper restored `SleepDisabled=0` at elapsed 64.686 seconds, and all 20 post-resume samples through elapsed 109.75 seconds stayed at 0. Native Settings showed **Paused**, override off, no LidPilot assertions; RC1's false Recovery state did not recur. The pause reason, “Lease identity or immutable session parameters do not match,” is less specific than the observed lease expiry. Raw ignored report: `release-private/validation/2026-09-23/lease-expiry-rc2.json`, SHA-256 `e5e9188b5a53dfe31ac90cca91f05146dddcff1ecaaa2227400b91f7546092ee`.

For a separate helper-crash test, the operator explicitly restarted a fresh RC2 session and ran `sudo kill -KILL` against the independently verified root helper PID 97436. The read-only observer sampled lid, global override and launchd helper PID for 120 seconds. Initial state was lid open, override 1, PID 97436. At the first changed sample, elapsed 22.902 seconds, launchd reported replacement PID 98726 and `SleepDisabled=0`; no later sample through elapsed 119.228 seconds returned to 1. All 115 samples had valid reads. Native Settings showed Paused and override off rather than falsely asserting active protection. Raw ignored report: `release-private/validation/2026-09-23/helper-crash-rc2.jsonl`, SHA-256 `cb93a4617fe83b63178d9a84677b92b0c9a92f66edf534be5d3ae976be4415f9`. This proves cleanup by the first changed sample, not the exact sub-second restoration time or every possible helper-failure path.
