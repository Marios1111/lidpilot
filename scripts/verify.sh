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
plutil -lint Config/App-Info.plist Config/Helper-Info.plist \
  Config/LaunchDaemons/com.lidpilot.app.helper.plist \
  Config/LaunchDaemons/com.lidpilot.app.dev.helper.plist >/dev/null
ruby scripts/validate_release_metadata.rb --self-test
ruby scripts/validate_pages_site.rb --self-test
ruby scripts/test_homebrew_cask.rb
CLANG_MODULE_CACHE_PATH=/private/tmp/lidpilot-verify-module-cache xcrun swift scripts/verify_update_signature.swift --self-test

fail_on_match() {
  local pattern="$1"
  local message="$2"
  local output status
  shift 2

  if output="$(grep -REn "$pattern" "$@" 2>&1)"; then
    printf '%s\n' "$output" >&2
    printf '%s\n' "$message" >&2
    exit 1
  else
    status=$?
  fi

  if [[ "$status" -ne 1 ]]; then
    printf 'failed to scan %s with grep (exit status %s)\n' "$*" "$status" >&2
    [[ -z "$output" ]] || printf '%s\n' "$output" >&2
    exit "$status"
  fi
}

require_match() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  local status

  if grep -qE "$pattern" "$file"; then
    return 0
  else
    status=$?
  fi

  if [[ "$status" -eq 1 ]]; then
    printf '%s\n' "$message" >&2
    exit 1
  fi

  printf 'failed to scan %s with grep (exit status %s)\n' "$file" "$status" >&2
  exit "$status"
}

fail_on_match "AbandonProcessGroup|/bin/sh[[:space:]]+-c|sudo[[:space:]]|osascript" \
  "forbidden privileged command shortcut found in release/build configuration" \
  Config

require_match \
  'Contents/Library/HelperTools/LidPilotHelper' \
  Config/LaunchDaemons/com.lidpilot.app.helper.plist \
  "LaunchDaemon BundleProgram is missing or points outside the app bundle"

fail_on_match \
  'SUPopSystemProfile' \
  "Sparkle system profiling must use SUEnableSystemProfiling and remain disabled" \
  Config/App-Info.plist

require_match \
  '<key>SUEnableSystemProfiling</key>' \
  Config/App-Info.plist \
  "Sparkle system profiling must use SUEnableSystemProfiling and remain disabled"

require_match \
  '<key>LSMultipleInstancesProhibited</key>' \
  Config/App-Info.plist \
  "application must prohibit multiple instances"

require_match \
  'CREATE_INFOPLIST_SECTION_IN_BINARY = YES' \
  LidPilot.xcodeproj/project.pbxproj \
  "helper Info.plist must be embedded in its Mach-O binary"

echo "static project, plist, script and disposable release checks passed"
