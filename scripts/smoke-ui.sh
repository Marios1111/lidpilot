#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DERIVED_DATA="${LIDPILOT_DERIVED_DATA:-/private/tmp/lidpilot-${UID}/DerivedData}"
APP_PATH="$DERIVED_DATA/Build/Products/Debug/LidPilot.app"

# Execute the actual Debug app with mock controls, then require verified mock
# cleanup and normal process exit. This is not a hardware or accessibility test.
python3 - "$APP_PATH" "$ROOT_DIR/build/native-previews" <<'PY'
import os
import pathlib
import subprocess
import sys

app = pathlib.Path(sys.argv[1])
output = pathlib.Path(sys.argv[2])
executable = app / 'Contents/MacOS/LidPilot'
if not executable.is_file():
    raise SystemExit('Build Debug before running the native smoke test.')
signature = subprocess.run(['/usr/bin/codesign', '-d', '--verbose=2', str(app)],
                           capture_output=True, text=True)
if signature.returncode or 'Signature=adhoc' not in signature.stderr:
    raise SystemExit('This smoke test requires the local ad-hoc Debug build.')
if not any(b'LIDPILOT_PREVIEW_CAPTURE_DIR' in binary.read_bytes()
           for binary in (app / 'Contents/MacOS').iterdir() if binary.is_file()):
    raise SystemExit('The Debug-only mock UI harness is missing; refusing to launch.')
output.mkdir(parents=True, exist_ok=True)
environment = os.environ.copy()
environment.update(LIDPILOT_UI_TESTING='1', LIDPILOT_PREVIEW_CAPTURE_DIR=str(output))
try:
    result = subprocess.run([str(executable)], env=environment, capture_output=True,
                            text=True, timeout=45)
except subprocess.TimeoutExpired:
    raise SystemExit('The isolated preview did not exit after cleanup within 45 seconds.')
(output / 'smoke.log').write_text(result.stdout + result.stderr)
if result.returncode or 'Native mock views rendered; session ended Off.' not in result.stdout:
    raise SystemExit('Native mock smoke failed; see build/native-previews/smoke.log.')
names = ['panel-off-light', 'panel-off-dark', 'panel-active', 'keep-screen-on', 'keep-mac-running', 'settings', 'welcome',
         'panel-tasks-light', 'panel-tasks-dark', 'panel-agent-ready', 'panel-agent-visible-while-on', 'panel-agent-hidden',
         'settings-agents', 'settings-agents-dark', 'settings-developer', 'settings-developer-dark', 'settings-shortcuts', 'settings-updates', 'settings-diagnostics',
         'product-off', 'product-follow-lid', 'product-keep-screen-on', 'product-keep-mac-running']
if not all((output / (name + '.png')).is_file() for name in names):
    raise SystemExit('Native mock smoke is missing a rendered artifact.')
print('Actual Debug app: mock activation, cleanup, rendering, and normal exit passed.')
print('Native menu/Form rendering, interaction, VoiceOver, and hardware remain separate checks.')
PY
