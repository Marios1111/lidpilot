#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROJECT="$ROOT_DIR/LidPilot.xcodeproj"
# Keep generated products out of synced Documents trees. Those providers can
# attach com.apple.provenance/Finder metadata to new files, which makes an
# otherwise valid macOS bundle fail its final codesign. Callers can override
# this for CI or a local non-synced checkout.
DERIVED_DATA="${LIDPILOT_DERIVED_DATA:-/private/tmp/lidpilot-${UID}/DerivedData}"
SOURCE_PACKAGES="${LIDPILOT_SOURCE_PACKAGES:-$ROOT_DIR/build/DerivedData/SourcePackages}"
PACKAGE_CACHE="${LIDPILOT_PACKAGE_CACHE:-$DERIVED_DATA/PackageCache}"
CONFIGURATION="${1:-Debug}"

case "$CONFIGURATION" in
  Debug|Release) ;;
  *)
    echo "usage: $0 [Debug|Release]" >&2
    exit 64
    ;;
esac

if [[ ! -d "$PROJECT" ]]; then
  ruby "$ROOT_DIR/scripts/generate-project.rb"
fi

if [[ ! -f "$ROOT_DIR/Package.swift" ]]; then
  echo "root Package.swift is required before building the app" >&2
  exit 1
fi

if [[ ! -f "$ROOT_DIR/App/LidPilotApp.swift" ]]; then
  echo "App sources are not present yet; refusing to run an empty app target" >&2
  exit 1
fi

if [[ "$CONFIGURATION" == "Release" && "${LIDPILOT_SIGNED_BUILD:-0}" == "1" ]]; then
  : "${DEVELOPMENT_TEAM:?Release builds require DEVELOPMENT_TEAM; do not guess the publisher team}"
  : "${LIDPILOT_DEVELOPER_IDENTITY:?Release builds require LIDPILOT_DEVELOPER_IDENTITY}"
  if [[ ! "$DEVELOPMENT_TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "DEVELOPMENT_TEAM must be a real ten-character Apple Team ID" >&2
    exit 1
  fi
  if [[ "$LIDPILOT_DEVELOPER_IDENTITY" == "-" || "$LIDPILOT_DEVELOPER_IDENTITY" == *"Apple Development"* ]]; then
    echo "Release builds require a Developer ID Application identity" >&2
    exit 1
  fi
  SIGNING_ARGS=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM" "CODE_SIGN_IDENTITY=$LIDPILOT_DEVELOPER_IDENTITY" "CODE_SIGN_STYLE=Manual" "OTHER_CODE_SIGN_FLAGS=--timestamp")
else
  # Local Debug and Release builds are deliberately ad-hoc. This is useful for
  # GUI and optimized compilation checks but is never a distributable release;
  # scripts/release.sh separately requires the real publisher identity.
  SIGNING_ARGS=("DEVELOPMENT_TEAM=" "CODE_SIGN_IDENTITY=-" "CODE_SIGN_STYLE=Manual")
fi

PROFILE_ARGS=('OTHER_SWIFT_FLAGS=$(inherited)')
case "${LIDPILOT_PROFILE_BUILD:-0}" in
  0) ;;
  1) PROFILE_ARGS=('OTHER_SWIFT_FLAGS=$(inherited) -DLIDPILOT_PROFILE') ;;
  *) echo "LIDPILOT_PROFILE_BUILD must be 0 or 1" >&2; exit 64 ;;
esac

mkdir -p "$DERIVED_DATA"
xcodebuild \
  -project "$PROJECT" \
  -scheme LidPilot \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES" \
  -packageCachePath "$PACKAGE_CACHE" \
  -disablePackageRepositoryCache \
  -destination "platform=macOS,arch=arm64" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=$([[ "$CONFIGURATION" == "Debug" ]] && echo YES || echo NO) \
  "${SIGNING_ARGS[@]}" \
  "${PROFILE_ARGS[@]}" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/LidPilot.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "xcodebuild completed without the expected app: $APP_PATH" >&2
  exit 1
fi
echo "built $APP_PATH"
