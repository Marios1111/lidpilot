#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRATCH_ROOT="${LIDPILOT_SWIFT_SCRATCH_ROOT:-/private/tmp/lidpilot-swift-${UID}}"
mkdir -p "$SCRATCH_ROOT/ModuleCache" "$SCRATCH_ROOT/Cache" "$SCRATCH_ROOT/root" "$SCRATCH_ROOT/core"

if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
  echo "root Package.swift is required before running tests" >&2
  exit 1
fi

export CLANG_MODULE_CACHE_PATH="$SCRATCH_ROOT/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$SCRATCH_ROOT/ModuleCache"

echo "testing root package"
(cd "$ROOT_DIR" && swift test --disable-sandbox --scratch-path "$SCRATCH_ROOT/root" --cache-path "$SCRATCH_ROOT/Cache")

if [[ -f "$ROOT_DIR/Core/Package.swift" ]]; then
  echo "testing Core package"
  (cd "$ROOT_DIR/Core" && swift test --disable-sandbox --scratch-path "$SCRATCH_ROOT/core" --cache-path "$SCRATCH_ROOT/Cache")
fi
