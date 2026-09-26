# Signed development/production coexistence — September 27, 2026

Production: installed uninstrumented RC10, source `d74d767`, bundle build 10.
Development: retained separately signed Debug candidate, bundle build 8,
`com.lidpilot.app.dev`, Developer ID Team `L69774LN97`. This is an identity/registration
check, not a final-source development runtime regression.

Both apps remained Off throughout; independent SleepDisabled=0 before and after.
The development app presented its own welcome flow and isolated defaults. Its
helper initially required approval. The owner approved the temporary registration
and authenticated directly through macOS. Native Refresh then reported Approved,
Session Off and override off, establishing development XPC reachability.

Independent launchd inspection showed both services running simultaneously:

| Service | Parent bundle | Build | PID | Exact signing ID / Team |
| --- | --- | --- | --- | --- |
| Production | com.lidpilot.app | 10 | 11649 | com.lidpilot.app.helper / L69774LN97 |
| Development | com.lidpilot.app.dev | 8 | 24420 | com.lidpilot.app.dev.helper / L69774LN97 |

Development Remove Helper was completed through its ordinary confirmation flow,
after native Off verification. Settings reported Not installed / Off / override off.
The development app was quit normally. Independent process inspection then found
only production app PID 9596; the development launchd service was absent (exit 113),
while production helper PID 11649 and parent build 10 remained unchanged.
SleepDisabled=0 remained. Only one running LidPilot menu-bar app was left.

**PASS:** distinct signed registrations, development helper reachability, isolated
welcome/default state, normal development helper removal and unchanged production
helper registration. No active simultaneous ownership test was performed. Shared
SleepDisabled conflict/fencing behavior retains its automated evidence; this record
does not claim a live two-session conflict or genuine different-Team rejection.
The stopped local development bundle is retained as a test artifact, not installed
in /Applications or left running.
