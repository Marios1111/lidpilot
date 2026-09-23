# Closed-lid and lease validation — 2026-09-23

This record extends [the RC1 native validation](2026-09-21-native-and-release.md); it is not stable V1 approval. Tested app: installed, Developer ID signed/notarized LidPilot 1.0.0 (1), helper build 1, team `L69774LN97`. Source revision for the installed RC1 is `67a176b8b9b17be88d29d9225df2df61a4483b98`; the observer and lease probe are local validation tools and are not shipped in the app. Host: Apple M4 MacBook Air, macOS 27.2 (26B5086k), built-in display only, AC connected and charging, lid open before setup, one-minute macOS display-idle setting. The other controller's helper was present, but its override was independently read as off before LidPilot took ownership. The operator explicitly authorized and assisted with the physical test.

## G2: Keep Mac Running

The native menu panel started a one-hour Keep Mac Running session. Before closing, independent `pmset` read-back showed `SleepDisabled=1`, LidPilot's `PreventUserIdleSystemSleep` assertion present, and `PreventUserIdleDisplaySleep=0`. A harmless task appended a UTC and monotonic timestamp every second and sampled the lid sensor and sleep flag every five seconds.

The sensor reported closed for 50 consecutive samples, from 16:12:21.999 to 16:13:11.121 UTC. The observer recorded `SleepDisabled=1` throughout the complete 240-second run and a maximum timestamp gap of 1.0725 seconds, including closure. On reopening, the sensor reported open and the override remained owned until the separate recovery test below. The operator saw the built-in screen darken after about one minute and confirmed normal reopening. The macOS power log emitted a `Display is turned off` notification at 19:13:08 local, during the close/reopen transition; it also emitted `Display is turned on` at that instant. This is a visual report plus macOS display-policy evidence, not an electrical panel/backlight measurement or proof of immediate shutdown. No external display or dock was available; those topologies remain untested.

The ignored local raw trace is `release-private/validation/2026-09-23/keep-running-rc1.jsonl`, SHA-256 `d5d36241325a22f3eaf59e89590b8f2ebb1f5db087b6ab043b7e31c76292da04`.

## G3: independent helper lease expiry

With the lid independently read open and the same session still owned, a bounded local probe verified the exact installed GUI process path, sent `SIGSTOP` to that GUI only, sampled `pmset -g` once per second for 90 seconds, and resumed it in a `finally` block. The probe never wrote a power setting. The helper's 60-second lease and ten-second watchdog are implemented independently of the GUI.

The first sampled `SleepDisabled=0` occurred 65.018 seconds after suspension. The override stayed off in the final 20 post-resume samples; final sample was at 110.451 seconds. This establishes real cleanup on lease expiry and no re-acquisition during that post-resume window. It does not yet establish the native UI's recovered state, helper-crash behavior, or every failed read-back/restore path.

The ignored local raw report is `release-private/validation/2026-09-23/lease-expiry-rc1.json`, SHA-256 `714a698409da9fddce8458449461a57141ca50c34d800d09e82c0b9694fd6e07`.
