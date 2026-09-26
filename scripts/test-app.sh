#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRATCH_ROOT="${LIDPILOT_APP_TEST_SCRATCH_ROOT:-/private/tmp/lidpilot-app-tests-${UID}}"
SOURCE_PACKAGES="${LIDPILOT_SOURCE_PACKAGES:-$ROOT_DIR/build/DerivedData/SourcePackages}"
mkdir -p "$SCRATCH_ROOT" "$SOURCE_PACKAGES"
RUN_DIR="$(mktemp -d "$SCRATCH_ROOT/run.XXXXXXXX")"
mkdir -p "$RUN_DIR/ModuleCache" "$RUN_DIR/PackageCache"

if [[ ! -d "$ROOT_DIR/LidPilot.xcodeproj" ]]; then
  ruby "$ROOT_DIR/scripts/generate-project.rb"
fi
ruby "$ROOT_DIR/scripts/generate-project.rb" --check

export CLANG_MODULE_CACHE_PATH="$RUN_DIR/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$RUN_DIR/ModuleCache"

xcodebuild test \
  -project "$ROOT_DIR/LidPilot.xcodeproj" \
  -scheme LidPilot \
  -configuration Debug \
  -destination "platform=macOS,arch=arm64" \
  -only-testing:LidPilotAppTests/UpdateCoordinatorTests \
  -derivedDataPath "$RUN_DIR/DerivedData" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES" \
  -packageCachePath "$RUN_DIR/PackageCache" \
  -disablePackageRepositoryCache \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  CODE_SIGN_STYLE=Manual
