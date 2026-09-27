# Copy Status and temporary Settings Dock presence

Tested September 27 on the local ad-hoc Debug build with the Copy Status source
at `a3ea48e` and the eight-line Settings activation-policy edit present. Debug
and Release builds had both exited 0 with these edits. The Debug executable was
launched with `LIDPILOT_UI_TESTING=1`; its power controls were simulated, helper
mutations disabled and preferences isolated. This is native interaction
evidence, not a signed installed-candidate or physical power test.

- Open Settings from the preview gear: native Settings appeared normally.
- While Settings was open, the owner confirmed LidPilot appeared in both the
  Dock and Cmd-Tab. Computer's direct Dock inspection timed out; the visual
  result is owner-observed, not inferred from an activation-policy call.
- Diagnostics exposed an accessible Copy Status button. Clicking it and
  pasting into a new TextEdit document produced the expected plain-text status:
  Off, requested/effective modes None, simulated lid open/external power/nominal
  thermal state, both assertions off, last-read sleep override off, and physical
  panel power explicitly not measured. Version/build and helper status were
  included. No workload content or event history was copied.
- The disposable paste was undone and the empty TextEdit document closed.
- Closing Settings returned to the preview panel. The owner confirmed that
  LidPilot disappeared from both Dock and Cmd-Tab. Reopening Settings through
  the gear worked, with Off and override off still displayed.
- The panel menu exposed Copy Status. A subsequent automated Down/Return
  sequence activated the preview's Start Session instead of proving menu-key
  activation. That simulated session was immediately turned Off; no keyboard
  Copy Status pass is claimed from that sequence.

After the reopened Settings window closed, Computer reported no visible window.
Only the identified temporary Debug process (PID 23634) was terminated; its
launch process exited 143 as expected. The installed production app was a
distinct PID 33563 and was not stopped or reconfigured by this check. No
development helper was registered. The isolated preview does not establish
installed performance, exact click-to-visible latency, minimized-window Dock
behavior or a complete final VoiceOver/accessibility regression.
