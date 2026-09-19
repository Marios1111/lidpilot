#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT_DIR"

for script in scripts/*.sh script/*.sh; do
  [[ -f "$script" ]] || continue
  bash -n "$script"
done
for script in scripts/*.rb; do
  [[ -f "$script" ]] || continue
  ruby -c "$script" >/dev/null
done

ruby scripts/generate-project.rb --check
plutil -lint Config/App-Info.plist Config/Helper-Info.plist Config/LaunchDaemons/com.lidpilot.app.helper.plist >/dev/null
ruby scripts/validate_release_metadata.rb --self-test
CLANG_MODULE_CACHE_PATH=/private/tmp/lidpilot-verify-module-cache xcrun swift scripts/verify_update_signature.swift --self-test

if rg -n "AbandonProcessGroup|/bin/sh[[:space:]]+-c|sudo[[:space:]]|osascript" Config; then
  echo "forbidden privileged command shortcut found in release/build configuration" >&2
  exit 1
fi

if ! rg -q 'Contents/Library/HelperTools/LidPilotHelper' Config/LaunchDaemons/com.lidpilot.app.helper.plist; then
  echo "LaunchDaemon BundleProgram is missing or points outside the app bundle" >&2
  exit 1
fi

if rg -q 'SUPopSystemProfile' Config/App-Info.plist || ! rg -q '<key>SUEnableSystemProfiling</key>' Config/App-Info.plist; then
  echo "Sparkle system profiling must use SUEnableSystemProfiling and remain disabled" >&2
  exit 1
fi

if ! rg -q '<key>LSMultipleInstancesProhibited</key>' Config/App-Info.plist; then
  echo "application must prohibit multiple instances" >&2
  exit 1
fi

if ! rg -q 'CREATE_INFOPLIST_SECTION_IN_BINARY = YES' LidPilot.xcodeproj/project.pbxproj; then
  echo "helper Info.plist must be embedded in its Mach-O binary" >&2
  exit 1
fi

echo "static project, plist, script and disposable release checks passed"
