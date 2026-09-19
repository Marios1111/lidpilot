#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CONFIGURATION="${1:-Debug}"
DERIVED_DATA="${LIDPILOT_DERIVED_DATA:-/private/tmp/lidpilot-${UID}/DerivedData}"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/LidPilot.app"
EXECUTABLE="$APP_PATH/Contents/MacOS/LidPilot"

"$ROOT_DIR/scripts/build.sh" "$CONFIGURATION"

# A running app owns session state and may be coordinating the helper. Never
# kill it from a convenience script. Ask the operator to quit it normally and
# retry, preserving the app's cleanup path.
if [[ -x "$EXECUTABLE" ]] && pgrep -f -- "$EXECUTABLE" >/dev/null 2>&1; then
  echo "LidPilot is already running; quit it normally and rerun this command" >&2
  exit 2
fi

open "$APP_PATH"
echo "launched $APP_PATH"
