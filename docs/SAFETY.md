# Safety contract

LidPilot decides whether it may request wakefulness. It does not certify a
Mac's physical temperature, battery health, display power, ventilation, network
availability, or workload success. The safety engine is deliberately
conservative: uncertainty withdraws LidPilot's request rather than granting a
longer session.

## Safety order

The coordinator and helper follow this order when events race:

1. Recovery failure and unresolved ownership remain visible and block new
   activation.
2. Mandatory safety observations and deadline expiry stop the session.
3. An explicit user Stop invalidates pending work.
4. A selected mode may continue only after a fresh preflight and verified
   helper/assertion state.

Every start, stop, mode transition, and helper operation carries a generation.
A delayed response from an older generation cannot activate a newer session.
There is no automatic resume after thermal, battery, Low Power Mode, stale
observation, helper, or ownership pauses.

Manual and task requests have independent ends. The V2 arbiter releases each
capability only after its last relevant request ends, while mandatory safety
withdraws all requests. System and display assertions use independent bounded
timeouts. Same-owner helper lease replacement cannot enable an unowned flag or
revive an expired lease. CLI, hooks and global shortcuts share these checks.
Workload waiting is not completion; absent events become unknown. Turn Off and
safety pauses disarm agent hooks, and late events cannot restart them.

## Required observations

`PowerSnapshot` records a `ClockSample`, lid state, power source, optional
battery percentage, thermal level, optional Low Power Mode state, optional
external-display count, and sampled sleep-flag state. `unknown` is a value, not
false.

Before a mode is allowed to continue, the sample must:

- have the same boot identity as the current clock;
- have a continuous timestamp no more than 30 seconds old and not in the
  future;
- not have a wall timestamp in the future;
- report known power source and thermal level;
- report a battery percentage in 0...100 when on battery;
- report lid, Low Power Mode, and external-display topology for Smart/Closed;
- use a valid policy floor of 10%, 20%, or 30%.

A stale, future, boot-mismatched, malformed, or unknown required observation
returns `unavailable`. A missing battery on external power does not by itself
block a mode; a missing battery while discharging does.

## Thermal policy

Nominal and fair thermal pressure may continue if other checks pass. Serious or
critical pressure returns `thermal` for every mode, regardless of battery or
charger state. The coordinator releases assertions and the helper lease, then
shows a safety pause. It does not kill an application, guarantee immediate
sleep, control fans, or restart after cooling.

The implementation uses macOS thermal-pressure state, not an invented CPU
temperature threshold. Keep the Mac on a ventilated surface and stop heavy
work when macOS reports elevated pressure.

## Battery and Low Power Mode

The battery floor is configurable to 10%, 20% (default), or 30%. A discharging
battery at or below the floor returns `battery` for all modes. Above the floor:

| Mode | On battery by default | `allowBattery` | Low Power Mode |
| --- | --- | --- | --- |
| Follow Lid | Pause with `unplugged` | May continue within the existing floor/deadline | Pause with `lowPower` when `respectLowPowerMode` is enabled |
| Keep Screen On | May continue | Does not grant a floor bypass | Does not pause solely for Low Power Mode |
| Keep Mac Running | Pause with `unplugged` | May continue within the existing floor/deadline | Pause with `lowPower` when `respectLowPowerMode` is enabled |

LidPilot never changes the macOS Low Power Mode preference. Reconnecting power
does not resume a safety-paused session without an explicit Start.

## Lid and display topology

Smart and Closed require a known lid state, known Low Power Mode state, and a
known nonnegative external-display count. Smart and Closed are armed while the
lid is open; the helper does not wait for a closed event before acquiring its
lease. The app drops Smart's display assertion on close and rechecks the lid,
safety snapshot, topology, and helper lease before restoring it on reopen.

When starting Smart or Closed, `requireOpenLid` is true. A closed or unknown lid
returns `lidUnknown` and no helper mutation is attempted. Display can be
started without the helper, but an explicit open-lid requirement still rejects
a closed or unknown lid when the caller requests that preflight.

The display assertion is app-scoped and does not claim control over another
application's assertions. Its native type prevents idle display sleep/dimming
while held. That means the desired “dim normally but never turn off” behavior
is not delivered by a hidden fallback; it remains G1 validation work. The app
does not write brightness, disable automatic brightness, fake input, or use a
black overlay as panel-off evidence.

## Global `SleepDisabled` ownership

The helper reads the global setting before acquisition. If it is already on and
LidPilot has no durable evidence that it owns the override, it refuses to
mutate the setting. If the flag changes unexpectedly while a lease is active,
the helper stops or enters recovery rather than repeatedly fighting another
controller.

The flag is not a reference-counted per-app API. A fresh `pmset -g` read-back of
`on` confirms the configuration reported by macOS's CLI. Apple's published
[implementation](https://github.com/apple-oss-distributions/IOKitUser/blob/323ead896d04424f87184d8f6ff0cce811aab106/pwr_mgt.subproj/IOPMEnergyPrefs.c) reads a system-wide preferences dictionary; this is not a
documented synchronous acknowledgment of kernel application. The shipped OS
binary was not independently reverse-engineered. Preserve independent reads
after writes and before replies, but do not describe them as a stronger applied
state guarantee. A read also does not prove that LidPilot is the sole writer,
that the panel is physically off, or that a user-requested sleep cannot be
affected by another program.

During development, a read-only host check reported `SleepDisabled=1`. That
pre-existing state is preserved. Ordinary tests use a mock driver and do not
clear, set, or otherwise alter the host's global power policy.

## Timing and bounds

The current engineering targets are:

| Bound | Target | Safety purpose |
| --- | ---: | --- |
| Core finite deadline | Hard monotonic or absolute end | A delayed UI/helper reply cannot extend a session |
| Helper lease | 60 seconds maximum | Expiry becomes a mandatory cleanup condition |
| App heartbeat | 15 seconds | Renew only while the coordinator is alive and safe |
| Helper watchdog check | 10 seconds | Observe expiry, safety, flag drift, and restore |
| `pmset` child command | 5 seconds + 0.25-second kill/reap window | Retain an inherited fence if child death remains unverified |
| XPC reply | 30 seconds | Bound app-side waiting and reconnect behavior |
| Helper queue | 1 outstanding payload globally, 4 clients | Bound admission and memory/work exposure |

Expiry is detected at a request pre-check or the next 10-second watchdog opportunity, followed by bounded command/read-back attempts. Physical restoration is not promised at exactly 60 seconds.

These are starting engineering bounds. They are not guarantees of scheduler,
kernel, hardware, or physical sleep timing. Changes need focused failure tests
and evidence from the actual supported system.

## What safety does not promise

LidPilot is not a bag detector, fan controller, battery-charge limiter, thermal
cutoff, remote-access service, or task supervisor. A closed session may keep a
local process runnable while network access, login state, display availability,
or the process itself still fails. A safety pause releases LidPilot's requests;
another program can still prevent sleep.

For a physical and signed-release checklist, see
[`HARDWARE_VALIDATION.md`](HARDWARE_VALIDATION.md). For recovery after an
uncertain flag or failed release, see [`RECOVERY.md`](RECOVERY.md).
