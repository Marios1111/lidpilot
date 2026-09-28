#!/usr/bin/env python3
"""Actual app/CLI integration with Debug-only mock power controls. No helper install."""
import json
import os
from pathlib import Path
import pty
import select
import signal
import socket
import subprocess
import sys
import tempfile
import time

root = Path(__file__).resolve().parents[1]
derived = Path(os.environ.get("LIDPILOT_DERIVED_DATA", f"/private/tmp/lidpilot-{os.getuid()}/DerivedData"))
bundle = derived / "Build/Products/Debug/LidPilot.app"
app = bundle / "Contents/MacOS/LidPilot"
cli = bundle / "Contents/MacOS/lidpilot-cli"
signature = subprocess.run(["codesign", "-d", "--verbose=2", str(bundle)], capture_output=True, text=True)
assert signature.returncode == 0 and "Signature=adhoc" in signature.stderr
assert any(b"LIDPILOT_CONTROL_TESTING" in path.read_bytes() for path in app.parent.iterdir() if path.is_file())
assert cli.is_file() and not os.path.samefile(app, cli)
endpoint = Path(f"/private/tmp/lidpilot-control-{os.getuid()}/preview.sock")
if endpoint.exists():
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as probe:
        probe.settimeout(1)
        assert probe.connect_ex(str(endpoint)) != 0, "Close the previous mock preview before this test."


def invoke(*args, expected=0, payload=None):
    result = subprocess.run([str(cli), "--preview", *args], input=payload, capture_output=True, text=True, timeout=10)
    assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
    return result


def status():
    return json.loads(invoke("status", "--json").stdout)["status"]


def hook(event, turn="turn", **fields):
    payload = {"hook_event_name": event, "session_id": "smoke", "turn_id": turn,
               "prompt": "DO-NOT-EXPORT", "transcript_path": "/private/DO-NOT-EXPORT", **fields}
    result = invoke("hook", "codex", "--adapter-version", "0.154.0", payload=json.dumps(payload))
    assert result.stdout.strip() == "{}"


def tty_command(command, input_bytes, expected):
    child, terminal = pty.fork()
    if child == 0:
        os.execv(str(cli), [str(cli), "--preview", "run", "--mode", "display", "--", "/bin/sh", "-c", command])
    output = b""
    try:
        end = time.monotonic() + 8
        while b"READY" not in output and time.monotonic() < end:
            if select.select([terminal], [], [], 0.2)[0]:
                output += os.read(terminal, 4096)
        assert b"READY" in output, output
        os.write(terminal, input_bytes)
        while time.monotonic() < end:
            pid, result = os.waitpid(child, os.WNOHANG)
            if pid:
                assert os.waitstatus_to_exitcode(result) == expected, (result, output)
                return
            if select.select([terminal], [], [], 0.1)[0]:
                try:
                    output += os.read(terminal, 4096)
                except OSError:
                    pass
        raise AssertionError("TTY command did not complete")
    finally:
        os.close(terminal)
        try:
            os.kill(child, signal.SIGTERM)
        except ProcessLookupError:
            pass


environment = dict(os.environ, LIDPILOT_UI_TESTING="1", LIDPILOT_CONTROL_TESTING="1")
with tempfile.TemporaryDirectory(prefix="lidpilot-cli-smoke-", dir="/private/tmp") as directory:
    with open(Path(directory) / "app.log", "w") as log:
        process = subprocess.Popen([str(app)], env=environment, stdout=log, stderr=log)
        try:
            end = time.monotonic() + 10
            ready = False
            while time.monotonic() < end and process.poll() is None:
                check = subprocess.run([str(cli), "--preview", "status"], capture_output=True, timeout=2)
                if check.returncode == 0:
                    ready = True
                    break
                time.sleep(0.1)
            assert ready, Path(log.name).read_text()
            assert status()["phase"] == "off"
            assert status()["appBuild"] == "13"
            started = json.loads(invoke("start", "--mode", "display", "--for", "30s").stdout)["status"]
            assert started["effectiveMode"] == "display"
            invoke("run", "--mode", "closed", "--", "/bin/sh", "-c", "exit 23", expected=23)
            assert status()["manualDeadline"] == started["manualDeadline"]
            assert status()["effectiveMode"] == "display"
            invoke("stop")
            invoke("tasks", "arm")
            hook("SessionStart")
            assert status()["phase"] == "off"
            hook("UserPromptSubmit")
            hook("SubagentStart", agent_id="child")
            hook("PermissionRequest")
            waiting = status()
            assert any(r["state"] == "waiting" for r in waiting["workloads"]), waiting
            hook("Stop")
            hook("PreToolUse", tool_use_id="continued")
            assert status()["phase"] == "active"
            hook("SubagentStop", agent_id="child")
            hook("Stop")
            time.sleep(3.3)
            assert status()["phase"] == "off"
            report = Path(directory) / "report.json"
            invoke("diagnostics", "--output", str(report))
            assert "DO-NOT-EXPORT" not in report.read_text()
            assert json.loads(invoke("diagnostics", "--output", str(report), expected=73).stderr)["code"] == 73
            invoke("stop")
            hook("PreToolUse", tool_use_id="late")
            assert status()["phase"] == "off" and not status()["integrationsArmed"]
            tty_command('printf "READY\\n"; read answer; test "$answer" = hello; exit 7', b"hello\n", 7)
            tty_command('printf "READY\\n"; exec /bin/sleep 30', b"\x03", 130)
            assert status()["phase"] == "off"
            invoke("install", "--directory", directory)
            invoke("install", "--directory", directory, expected=73)
            invoke("uninstall", "--directory", directory)
            config = Path(directory) / "hooks.json"
            config.write_text('{"custom":true,"hooks":{"Stop":[{"hooks":[{"type":"command","command":"existing"}]}]}}')
            original = json.loads(config.read_text())
            for action in ["install", "install", "remove"]:
                invoke("hooks", action, "codex", "--config", str(config), "--adapter-version", "0.154.0")
            assert json.loads(config.read_text()) == original
            if "--sustained-hooks" in sys.argv:
                invoke("start", "--mode", "closed", "--for", "2h")
                invoke("tasks", "arm")
                hook("UserPromptSubmit", turn="busy")
                end = time.monotonic() + 65
                sequence = 0
                while time.monotonic() < end:
                    hook("PreToolUse", turn="busy", tool_use_id=f"busy-{sequence}")
                    sequence += 1
                    time.sleep(1)
                # No status request during this interval: it would renew the
                # lease and mask timer starvation from frequent hook events.
                assert status()["phase"] == "active"
                invoke("stop")
                print("PASS: 65 seconds of continuous hooks do not starve the helper heartbeat.")
            print("PASS: real CLI/app IPC, overlapping requests, hooks/continuation/subtasks, privacy, Off, exit status, TTY input/Ctrl-C, reversible install/config.")
        finally:
            if process.poll() is None:
                try:
                    invoke("stop")
                finally:
                    process.terminate()
                    process.wait(timeout=10)
