# Developer tools and workload sessions

**LidPilot 2.0.0** includes the blueprint's V1.1 conveniences and V2 workload
sessions.
V2.1 rules/schedules and V2.2 Shortcuts/URL automation are separate roadmap work.

## Enable the CLI

Open LidPilot, finish the welcome screen, then enable **Settings → Developer
Tools → Allow local CLI control**. This permits programs running as your macOS
user to request the same actions as the app. The app must remain running.
Closed-lid modes still require the signed helper's normal approval and a safe,
open-lid starting state. The CLI never runs privileged commands.

Use **Install CLI in a Folder…** to select an existing, user-owned bin directory,
or invoke the bundled tool explicitly:

```sh
"/Applications/LidPilot.app/Contents/MacOS/lidpilot-cli" install --directory "$HOME/.local/bin"
lidpilot status --json
lidpilot start --mode display --for 2h
lidpilot start --mode smart --for 4h
lidpilot stop
lidpilot diagnostics --output ./lidpilot-report.json
```

Create your bin directory first if necessary; add it to PATH yourself if wanted.
Installation creates only a `lidpilot` symlink, refuses to overwrite anything,
and never edits shell configuration. `lidpilot uninstall --directory <folder>`
removes only a link to this executable. Export refuses to replace an existing
report. The embedded name differs from `LidPilot` beyond case so both executables
work on ordinary macOS volumes.

Start uses the app's manual request. Changing its mode preserves an active
deadline; starting after expiry creates a fresh deadline. Supported duration
suffixes are `s`, `m`, `h`, and `d`, with a seven-day manual maximum.

Status and control replies use JSON `schemaVersion: 1`, numeric `code`, message,
and status. Status separates requested/effective mode, manual request, observed
power sample, helper read-back, assertion state, workload records, last confirmed
operation, next step, app version/build, and sample time. Absent optional fields
are omitted. Exported dates are ISO 8601. A successful read of status does not
mean every reported observation is known or every task is protected.

| Exit | Meaning |
| --- | --- |
| 0 | Action confirmed, or query completed; inspect the reported phase |
| 64 | Invalid input or unsupported schema/event |
| 69 | App/control endpoint unavailable |
| 73 | Ownership, installation destination, or file conflict |
| 75 | Outcome or cleanup not verified; inspect status before retrying |
| 77 | Welcome/helper approval required |
| 78 | Safety, update, recovery, disarmed hooks, or expired protection blocks the action |

## Keep awake for a command

```sh
lidpilot run --mode closed -- make test
lidpilot run --mode display --for 2h -- /usr/bin/python3 long_job.py
```

Protection must be confirmed before the command is launched. Output and stdin
remain attached to the command. The wrapper preserves its exit status, forwards
INT/TERM/HUP/QUIT, supports foreground terminal input and suspension/resumption,
and waits for children in its process group after the initial command exits.
Children that deliberately detach into another process group/session are outside
the wrapper's scope; supervise them separately or use a manual timer.

The default maximum is eight hours; `--for` accepts one minute through 24 hours.
The wrapper sends heartbeats every ten seconds; missing heartbeats release its
hold after 60 seconds. Safety or Turn Off can end protection while the command
continues. A warning reports lost protection; LidPilot never kills the workload
to enforce a power policy. Once a child launches, `run` returns the child status,
including `128 + signal` for signal termination, even if cleanup needs attention.

## Agent hooks (experimental)

Adapters are pinned to **Codex 0.154.0** and **Claude Code 2.1.112**. Their
allowlisted event fixtures are tested; complete live G6 acceptance is not yet
established. Check your installed version before opting in. Do not assume newer
agent versions or the desktop app expose the same payloads.

For an existing configuration directory, install only the integration you use:

```sh
lidpilot hooks install codex --config "$HOME/.codex/hooks.json" --adapter-version 0.154.0
lidpilot hooks install claude --config "$HOME/.claude/settings.json" --adapter-version 2.1.112
lidpilot tasks arm
```

The user configuration locations and trust/enablement requirements are described
in the official [Codex hooks documentation](https://developers.openai.com/codex/hooks)
and [Claude Code hooks reference](https://code.claude.com/docs/en/hooks).
Provider trust review or an administrator disabling hooks can prevent delivery;
LidPilot does not change those policies. Restart the agent after editing hooks
when that version requires it.

The installer adds marked command handlers, preserves unrelated JSON keys and
existing handlers, and refuses unsafe paths or concurrent file changes. It does
not arm hooks, start an agent, edit TOML, or install a shell startup script.
Remove just LidPilot's handlers with the matching command:

```sh
lidpilot tasks disarm
lidpilot hooks remove codex --config "$HOME/.codex/hooks.json" --adapter-version 0.154.0
lidpilot hooks remove claude --config "$HOME/.claude/settings.json" --adapter-version 2.1.112
```

Hook handlers return neutral `{}` and exit zero, including when LidPilot is
unavailable. They never grant approval or request continuation. Input is capped
at 1 MiB with a 0.75-second input deadline; local IPC has a 0.5-second timeout.
Only event name, opaque identifiers, pinned adapter version, receipt time, and
bounded outcome metadata survive projection. Prompts, messages, tool arguments,
working directories, and transcript paths are discarded; transcripts are never
opened. Command arguments are not sent to the app either.

Codex's correlated Stop settles for three seconds; continued work resumes that
turn's request within its original maximum. Waiting uses a configurable grace
(30 seconds–10 minutes, default two minutes). A parent ending does not cancel an
active subtask. Session disconnect/cancel is unknown, never success.

**Claude limitation:** main-turn Stop, failure, and waiting signals without a
turn ID cannot safely distinguish an older turn from a newer prompt. Those
signals do not end or shorten the newest turn. Its last confirmed work state
expires as unknown at the missing-event limit (one–30 minutes, default 15).
Subtask IDs are correlated to their original turn. Use a manual timer when
predictable protection is needed; this limitation keeps the adapter experimental.

## One policy, independent requests

A manual lecture, command, and agent tasks may overlap. Each keeps its own mode,
deadline, state and identity. Finishing a build releases only that build. The app
combines display and closed-lid needs; its system and display assertion timeouts
are independent. Waiting and missing events never imply successful completion.
Optional notifications distinguish confirmed command exit from an agent turn
ending and mention remaining requests or unverified cleanup.

Turn Off, mandatory safety, sleep/session change, and quitting release requests;
hooks require explicit re-arming after Stop or a safety pause. Launch and updates
always start Off with hooks disarmed. Disarming hooks alone preserves manual and
supervised-command requests. At most 128 task records and 512 remembered task
identities are admitted per active period; capacity exhaustion asks for Stop and
explicit re-arm instead of evicting active work.

## Shortcuts, diagnostics and updates

Settings → Shortcuts starts with no assignments. Choose a key with Command plus
another modifier, or Control + Option. Conflicts preserve the previous shortcut;
Clear unregisters it. No Accessibility permission or keystroke monitoring is used.
Actions open the panel, toggle Start/Turn Off, or choose a mode through the same
coordinator.

Settings → Diagnostics shows the last confirmed operation, observation time and
next recovery step. Copy Status is local; report export is explicitly requested
and never uploaded.

Settings → Updates selects **In-app (Sparkle)**, **Homebrew**, or **Manual**.
Homebrew path/receipt detection is a hint and can be overridden. Homebrew/manual
ownership disables Sparkle checks and installation; choosing Sparkle restores
its saved check preference. End sessions before an external Homebrew upgrade:
the app cannot veto another process replacing its bundle. See [verification](VERIFICATION.md) for signed-helper, deadline, crash cleanup
and upgrade evidence.
