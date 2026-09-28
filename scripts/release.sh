#!/bin/bash
set -euo pipefail

# This driver prepares a release locally. It has no GitHub, Pages, or upload
# path by design. Every operation that can contact Apple or sign bytes is an
# explicit stage (or part of the explicitly requested `all` sequence).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROJECT="$ROOT_DIR/LidPilot.xcodeproj"
CONFIG_FILE="$ROOT_DIR/Version.xcconfig"
CHANGELOG="$ROOT_DIR/CHANGELOG.md"
VALIDATOR="$ROOT_DIR/scripts/validate_release_metadata.rb"
RELEASE_ROOT="${LIDPILOT_RELEASE_ROOT:-/private/tmp/lidpilot-release-${UID}}"
DERIVED_DATA="${LIDPILOT_RELEASE_DERIVED_DATA:-/private/tmp/lidpilot-release-${UID}/DerivedData}"
SOURCE_PACKAGES="${LIDPILOT_SOURCE_PACKAGES:-$ROOT_DIR/build/DerivedData/SourcePackages}"
PACKAGE_CACHE="${LIDPILOT_PACKAGE_CACHE:-/private/tmp/lidpilot-release-${UID}/PackageCache}"
STATE_FILE="${LIDPILOT_RELEASE_STATE_FILE:-$ROOT_DIR/release-private/last-release.json}"

COMMAND="${1:-dry-run}"
case "$COMMAND" in
  dry-run|preflight|archive|export|notarize-app|dmg|sign-update|manifest|all) ;;
  *)
    echo "usage: $0 [dry-run|preflight|archive|export|notarize-app|dmg|sign-update|manifest|all]" >&2
    exit 64
    ;;
esac

xcconfig_value() {
  local key="$1"
  awk -F= -v wanted="$key" '
    $1 ~ "^[[:space:]]*" wanted "[[:space:]]*$" {
      value = $0
      sub(/^[^=]*=/, "", value)
      sub(/[[:space:]]*\/\/.*$/, "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "$CONFIG_FILE"
}

VERSION="$(xcconfig_value MARKETING_VERSION)"
BUILD="$(xcconfig_value CURRENT_PROJECT_VERSION)"
RELEASE_CONFIGURATION="$(ruby "$VALIDATOR" --resolve-config --version "$VERSION")"
IFS=$'\t' read -r RELEASE_CHANNEL RELEASE_LABEL LIDPILOT_GITHUB_REPOSITORY LIDPILOT_PAGES_URL LIDPILOT_RELEASE_DOWNLOAD_URL RELEASE_HARDWARE_VALIDATION LIDPILOT_SPARKLE_PUBLIC_KEY <<<"$(ruby -rjson -e '
  configuration = JSON.parse(STDIN.read)
  keys = %w[channel releaseLabel repository feedURL downloadURL hardwareValidation sparklePublicKey]
  STDOUT.write(keys.map { |key| configuration.fetch(key) }.join("\t"))
' <<<"$RELEASE_CONFIGURATION")"
PROFILE_ARGS=('OTHER_SWIFT_FLAGS=$(inherited)')
case "${LIDPILOT_PROFILE_BUILD:-0}" in
  0) ;;
  1)
    [[ "$RELEASE_CHANNEL" == rc ]] || { echo "Profiling is allowed only for an explicit RC, never stable" >&2; exit 64; }
    PROFILE_ARGS=('OTHER_SWIFT_FLAGS=$(inherited) -DLIDPILOT_PROFILE')
    ;;
  *) echo "LIDPILOT_PROFILE_BUILD must be 0 or 1" >&2; exit 64 ;;
esac
RELEASE_ID="${RELEASE_LABEL}-${BUILD}"
if [[ "${LIDPILOT_PROFILE_BUILD:-0}" == 1 ]]; then RELEASE_ID="${RELEASE_ID}-profile"; fi
STAGE_ROOT="$RELEASE_ROOT/$RELEASE_ID"
ARCHIVE_PATH="$STAGE_ROOT/LidPilot.xcarchive"
EXPORT_DIR="$STAGE_ROOT/export"
UPDATE_DIR="$STAGE_ROOT/update"
EXPORT_OPTIONS="$STAGE_ROOT/ExportOptions.plist"
APP_PATH="$EXPORT_DIR/LidPilot.app"
DMG_PATH="$STAGE_ROOT/LidPilot-${RELEASE_LABEL}.dmg"
NOTARY_APP_ARCHIVE="$STAGE_ROOT/LidPilot-${RELEASE_LABEL}-notary.zip"
UPDATE_ARCHIVE="$UPDATE_DIR/LidPilot-${RELEASE_LABEL}.zip"
APPCAST_PATH="$UPDATE_DIR/appcast.xml"
NOTES_PATH="$UPDATE_DIR/LidPilot-${RELEASE_LABEL}.md"
MANIFEST_PATH="$STAGE_ROOT/manifest.json"

PREFLIGHT_FAILURES=0
SPARKLE_SIGNING_ARGS=()
VALIDATOR_SIGNING_ARGS=()

release_error() {
  printf 'release preflight: %s\n' "$1" >&2
  PREFLIGHT_FAILURES=$((PREFLIGHT_FAILURES + 1))
}

has_placeholder() {
  case "$1" in
    *example.com*|*example.org*|*example.net*|*example.test*|*localhost*|*127.0.0.1*|*.invalid*|*YOUR*|*CHANGE_ME*|*REPLACE_ME*|*\<*\>* ) return 0 ;;
  esac
  return 1
}

check_real_url() {
  local value="$1"
  if has_placeholder "$value"; then
    return 1
  fi
  ruby -ruri -e '
    value = ARGV.fetch(0)
    uri = URI.parse(value)
    abort unless uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
  ' "$value" >/dev/null 2>&1
}

check_regular_file() {
  local path="$1"
  [[ -f "$path" && ! -L "$path" ]]
}

check_executable_file() {
  local path="$1"
  check_regular_file "$path" && [[ -x "$path" ]]
}

check_directory() {
  local path="$1"
  [[ -d "$path" && ! -L "$path" ]]
}

check_env() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    release_error "$name is required"
  fi
}

check_identity() {
  local name="$1"
  local value="${!name:-}"
  [[ -z "$value" ]] && return
  if [[ "$value" == "-" || "$value" == *"Apple Development"* || "$value" == *"Apple Distribution"* ]]; then
    release_error "$name must be a real Developer ID identity"
    return
  fi
  if command -v security >/dev/null 2>&1; then
    local identities
    identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    if [[ "$identities" != *"$value"* ]]; then
      release_error "$name was not found in the local codesigning keychain"
    fi
  fi
}

check_private_key() {
  local path="${SPARKLE_PRIVATE_KEY_FILE:-}"
  [[ -z "$path" ]] && return
  if ! check_regular_file "$path"; then
    release_error "SPARKLE_PRIVATE_KEY_FILE must point to a regular, non-symlink file"
    return
  fi
  local mode
  mode="$(stat -f '%Lp' "$path" 2>/dev/null || true)"
  if [[ -n "$mode" && "$mode" != "600" && "$mode" != "400" && "$mode" != "640" ]]; then
    release_error "SPARKLE_PRIVATE_KEY_FILE must not be broadly readable (mode $mode)"
  fi
}

check_publication_urls() {
  local repository="${LIDPILOT_GITHUB_REPOSITORY:-}"
  local pages_url="${LIDPILOT_PAGES_URL:-}"
  local download_url="${LIDPILOT_RELEASE_DOWNLOAD_URL:-}"
  [[ -z "$repository" || -z "$pages_url" || -z "$download_url" ]] && return 0
  ruby -ruri -e '
    repository, release_label, channel, pages_value, download_value = ARGV
    abort unless repository.match?(/\A[A-Za-z0-9-]+\/[A-Za-z0-9_.-]+\z/)
    expected_feed = channel == "stable" ? "https://lidpilot.app/updates/appcast.xml" : "https://lidpilot.app/rc/appcast.xml"
    abort unless pages_value == expected_feed
    expected = "https://github.com/#{repository}/releases/download/v#{release_label}/LidPilot-#{release_label}.zip"
    abort unless download_value == expected
  ' "$repository" "$RELEASE_LABEL" "$RELEASE_CHANNEL" "$pages_url" "$download_url" >/dev/null 2>&1
}

check_release_notes_heading() {
  if ! check_regular_file "$CHANGELOG"; then
    release_error "CHANGELOG.md is missing"
    return
  fi
  if ! grep -Eq "^##[[:space:]]+(\\[)?${VERSION}(\\])?([[:space:]]|$)" "$CHANGELOG"; then
    release_error "CHANGELOG.md has no release-notes section for ${VERSION}"
  fi
}

check_monotonic_build() {
  if ! ruby "$VALIDATOR" --check-monotonic-build --build "$BUILD" --state-file "$STATE_FILE" >/dev/null 2>&1; then
    release_error "build ${BUILD} is not greater than the last recorded release in ${STATE_FILE}"
  fi
}

preflight() {
  local PREFLIGHT_COMMAND="${1:-preflight}"
  if ! check_directory "$PROJECT"; then
    release_error "LidPilot.xcodeproj is missing"
  fi
  if ! check_regular_file "$CONFIG_FILE"; then
    release_error "Version.xcconfig is missing"
  fi
  if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "$BUILD" =~ ^[1-9][0-9]*$ ]]; then
    release_error "Version.xcconfig must contain numeric MARKETING_VERSION and positive CURRENT_PROJECT_VERSION"
  fi
  if ! grep -Eq '^[[:space:]]*ARCHS[[:space:]]*=[[:space:]]*arm64([[:space:]]|$)' "$CONFIG_FILE"; then
    release_error "release architecture must be arm64"
  fi
  if ! grep -Eq '^[[:space:]]*MACOSX_DEPLOYMENT_TARGET[[:space:]]*=[[:space:]]*15\.0([[:space:]]|$)' "$CONFIG_FILE"; then
    release_error "release deployment target must be macOS 15.0"
  fi
  if ! git -C "$ROOT_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
    release_error "the source tree is not a Git checkout"
  fi
  local status
  status="$(git -C "$ROOT_DIR" status --porcelain --untracked-files=all 2>/dev/null || true)"
  if [[ -n "$status" ]]; then
    release_error "the source tree must be clean before a release"
    printf '%s\n' "$status" | sed -n '1,20p' >&2
  fi
  if ! ruby "$ROOT_DIR/scripts/generate-project.rb" --check >/dev/null 2>&1; then
    release_error "generated Xcode project validation failed"
  fi
  if ! plutil -lint "$ROOT_DIR/Config/App-Info.plist" "$ROOT_DIR/Config/Helper-Info.plist" "$ROOT_DIR/Config/LaunchDaemons/com.lidpilot.app.helper.plist" >/dev/null 2>&1; then
    release_error "release plist validation failed"
  fi
  if ! check_regular_file "$ROOT_DIR/LidPilot.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"; then
    release_error "the Xcode SwiftPM Package.resolved lock is missing"
  elif ! grep -Eq '"version"[[:space:]]*:[[:space:]]*"2\.10\.0"' "$ROOT_DIR/LidPilot.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"; then
    release_error "Package.resolved does not pin Sparkle 2.10.0"
  fi
  check_release_notes_heading

  check_env LIDPILOT_GITHUB_REPOSITORY
  if [[ -n "${LIDPILOT_GITHUB_REPOSITORY:-}" && ! "$LIDPILOT_GITHUB_REPOSITORY" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$ ]]; then
    release_error "LIDPILOT_GITHUB_REPOSITORY must be owner/repository"
  fi
  check_env DEVELOPMENT_TEAM
  if [[ -n "${DEVELOPMENT_TEAM:-}" && ! "$DEVELOPMENT_TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
    release_error "DEVELOPMENT_TEAM must be the real ten-character Apple Team ID"
  fi
  check_env LIDPILOT_DEVELOPER_IDENTITY
  check_identity LIDPILOT_DEVELOPER_IDENTITY
  check_env LIDPILOT_NOTARY_PROFILE
  check_env SPARKLE_TOOLS_DIR
  if [[ -n "${SPARKLE_TOOLS_DIR:-}" ]]; then
    check_executable_file "$SPARKLE_TOOLS_DIR/sign_update" || release_error "Sparkle 2.10.0 sign_update is missing or not executable: set SPARKLE_TOOLS_DIR to its bin directory"
    check_executable_file "$SPARKLE_TOOLS_DIR/generate_appcast" || release_error "Sparkle 2.10.0 generate_appcast is missing or not executable: set SPARKLE_TOOLS_DIR to its bin directory"
  fi
  if [[ -n "${SPARKLE_KEYCHAIN_ACCOUNT:-}" && -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
    release_error "choose SPARKLE_KEYCHAIN_ACCOUNT or SPARKLE_PRIVATE_KEY_FILE, not both"
  elif [[ -n "${SPARKLE_KEYCHAIN_ACCOUNT:-}" ]]; then
    if [[ ! "$SPARKLE_KEYCHAIN_ACCOUNT" =~ ^[A-Za-z0-9_.-]+$ ]]; then
      release_error "SPARKLE_KEYCHAIN_ACCOUNT must be an existing signing account name"
    fi
    SPARKLE_SIGNING_ARGS=(--account "$SPARKLE_KEYCHAIN_ACCOUNT")
    VALIDATOR_SIGNING_ARGS=(--keychain-account "$SPARKLE_KEYCHAIN_ACCOUNT")
  else
    check_env SPARKLE_PRIVATE_KEY_FILE
    check_private_key
    SPARKLE_SIGNING_ARGS=(--ed-key-file "${SPARKLE_PRIVATE_KEY_FILE:-}")
    VALIDATOR_SIGNING_ARGS=(--private-key-file "${SPARKLE_PRIVATE_KEY_FILE:-}")
  fi
  check_env LIDPILOT_SPARKLE_PUBLIC_KEY
  if [[ -n "${LIDPILOT_SPARKLE_PUBLIC_KEY:-}" ]] && has_placeholder "$LIDPILOT_SPARKLE_PUBLIC_KEY"; then
    release_error "LIDPILOT_SPARKLE_PUBLIC_KEY contains a placeholder"
  fi
  check_env LIDPILOT_PAGES_URL
  if [[ -n "${LIDPILOT_PAGES_URL:-}" ]] && ! check_real_url "$LIDPILOT_PAGES_URL"; then
    release_error "LIDPILOT_PAGES_URL must be a credential-free HTTPS appcast.xml URL"
  fi
  check_env LIDPILOT_RELEASE_DOWNLOAD_URL
  if [[ -n "${LIDPILOT_RELEASE_DOWNLOAD_URL:-}" ]]; then
    if ! check_real_url "$LIDPILOT_RELEASE_DOWNLOAD_URL"; then
      release_error "LIDPILOT_RELEASE_DOWNLOAD_URL must be a credential-free HTTPS URL"
    fi
    if [[ "$LIDPILOT_RELEASE_DOWNLOAD_URL" == */latest/* ]]; then
      release_error "release download URL must be immutable and must not use /latest/"
    fi
    if [[ "$LIDPILOT_RELEASE_DOWNLOAD_URL" != *"$RELEASE_LABEL"* && "$LIDPILOT_RELEASE_DOWNLOAD_URL" != *"v$RELEASE_LABEL"* ]]; then
      release_error "release download URL must identify release ${RELEASE_LABEL}"
    fi
    if [[ "${LIDPILOT_RELEASE_DOWNLOAD_URL##*/}" != "LidPilot-${RELEASE_LABEL}.zip" ]]; then
      release_error "release download URL must end in LidPilot-${RELEASE_LABEL}.zip"
    fi
  fi
  if [[ -n "${LIDPILOT_GITHUB_REPOSITORY:-}" && -n "${LIDPILOT_PAGES_URL:-}" && -n "${LIDPILOT_RELEASE_DOWNLOAD_URL:-}" ]] && ! check_publication_urls; then
    release_error "publication URLs must use the canonical lidpilot.app feed path for the selected channel and the exact immutable GitHub Release zip for ${RELEASE_LABEL}"
  fi
  if [[ "$RELEASE_CHANNEL" == "rc" ]]; then
    if [[ "$RELEASE_HARDWARE_VALIDATION" != "pending" ]]; then
      release_error "RC hardware validation must remain pending"
    fi
  elif [[ "${LIDPILOT_HARDWARE_APPROVED:-}" != "1" ]]; then
    release_error "LIDPILOT_HARDWARE_APPROVED=1 is required after the hardware checklist"
  fi
  case "${PREFLIGHT_COMMAND:-preflight}" in
    dry-run|preflight|archive|manifest|all) check_monotonic_build ;;
  esac
  for tool in xcodebuild xcrun hdiutil codesign ditto shasum; do
    command -v "$tool" >/dev/null 2>&1 || release_error "required host tool is missing: $tool"
  done
  if [[ "$PREFLIGHT_FAILURES" -gt 0 ]]; then
    return 1
  fi
  echo "release preflight passed for LidPilot ${RELEASE_LABEL} (${BUILD}, channel ${RELEASE_CHANNEL})"
}

ensure_stage_directory() {
  mkdir -p "$STAGE_ROOT"
}

require_archive() {
  if ! check_directory "$ARCHIVE_PATH"; then
    echo "missing archive; run '$0 archive' first: $ARCHIVE_PATH" >&2
    exit 1
  fi
}

require_exported_app() {
  if ! check_directory "$APP_PATH"; then
    echo "missing exported app; run '$0 export' first: $APP_PATH" >&2
    exit 1
  fi
}

write_export_options() {
  cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>Developer ID Application</string>
  <key>teamID</key>
  <string>${DEVELOPMENT_TEAM}</string>
</dict>
</plist>
EOF
  plutil -lint "$EXPORT_OPTIONS" >/dev/null
}

run_archive() {
  ensure_stage_directory
  if [[ -e "$ARCHIVE_PATH" ]]; then
    echo "refusing to overwrite existing archive: $ARCHIVE_PATH" >&2
    exit 1
  fi
  mkdir -p "$DERIVED_DATA" "$SOURCE_PACKAGES" "$PACKAGE_CACHE"
  xcodebuild \
    -project "$PROJECT" \
    -scheme LidPilot \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$DERIVED_DATA" \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES" \
    -packageCachePath "$PACKAGE_CACHE" \
    -disablePackageRepositoryCache \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    CODE_SIGN_IDENTITY="$LIDPILOT_DEVELOPER_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    OTHER_CODE_SIGN_FLAGS=--timestamp \
    SUFeedURL="$LIDPILOT_PAGES_URL" \
    SUPublicEDKey="$LIDPILOT_SPARKLE_PUBLIC_KEY" \
    "${PROFILE_ARGS[@]}" \
    archive
  echo "archived $ARCHIVE_PATH"
}

run_export() {
  require_archive
  ensure_stage_directory
  if [[ -e "$EXPORT_DIR" ]]; then
    echo "refusing to overwrite existing export directory: $EXPORT_DIR" >&2
    exit 1
  fi
  write_export_options
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS"
  require_exported_app
  echo "exported $APP_PATH"
}

verify_signed_bundle() {
  require_exported_app
  codesign --verify --deep --strict "$APP_PATH"
  local target metadata expected
  for target in "$APP_PATH" "$APP_PATH/Contents/Library/HelperTools/LidPilotHelper" "$APP_PATH/Contents/MacOS/lidpilot-cli"; do
    metadata="$(codesign -d --verbose=4 "$target" 2>&1)"
    [[ "$metadata" == *"TeamIdentifier=$DEVELOPMENT_TEAM"* ]] || { echo "publisher signing team mismatch" >&2; exit 1; }
    [[ "$metadata" == *"runtime"* ]] || { echo "hardened runtime is required" >&2; exit 1; }
    [[ "$metadata" == *"Timestamp="* ]] || { echo "secure signing timestamp is required" >&2; exit 1; }
  done
  for target in "$APP_PATH/Contents/MacOS/LidPilot" "$APP_PATH/Contents/Library/HelperTools/LidPilotHelper" "$APP_PATH/Contents/MacOS/lidpilot-cli"; do
    [[ "$(lipo -archs "$target")" == "arm64" ]] || { echo "app, helper, and CLI must be arm64 only" >&2; exit 1; }
  done
}

run_notarize_app() {
  verify_signed_bundle
  if [[ -e "$NOTARY_APP_ARCHIVE" ]]; then
    echo "refusing to overwrite existing notary archive: $NOTARY_APP_ARCHIVE" >&2
    exit 1
  fi
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_APP_ARCHIVE"
  xcrun notarytool submit "$NOTARY_APP_ARCHIVE" --keychain-profile "$LIDPILOT_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
  echo "notarized and stapled $APP_PATH"
}

run_dmg() {
  require_exported_app
  if [[ -e "$DMG_PATH" ]]; then
    echo "refusing to overwrite existing DMG: $DMG_PATH" >&2
    exit 1
  fi
  xcrun stapler validate "$APP_PATH" >/dev/null
  local dmg_root="$STAGE_ROOT/dmg-root"
  mkdir -p "$dmg_root"
  ditto "$APP_PATH" "$dmg_root/LidPilot.app"
  hdiutil create -volname "LidPilot ${RELEASE_LABEL}" -srcfolder "$dmg_root" -ov -format UDZO "$DMG_PATH"
  codesign --force --timestamp --sign "$LIDPILOT_DEVELOPER_IDENTITY" "$DMG_PATH"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$LIDPILOT_NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  echo "signed, notarized and stapled $DMG_PATH"
}

write_release_notes() {
  mkdir -p "$UPDATE_DIR"
  if ! awk -v version="$VERSION" '
    found && $0 ~ /^##[[:space:]]/ { exit }
    $0 ~ "^##[[:space:]]+(\\[)?" version "(\\])?([[:space:]]|$)" { found = 1; print; next }
    found { print }
    END { if (!found) exit 1 }
  ' "$CHANGELOG" > "$NOTES_PATH"; then
    echo "could not extract release notes for ${VERSION} from CHANGELOG.md" >&2
    exit 1
  fi
  [[ -s "$NOTES_PATH" ]] || { echo "release notes are empty: $NOTES_PATH" >&2; exit 1; }
}

run_sign_update() {
  verify_signed_bundle
  xcrun stapler validate "$APP_PATH" >/dev/null
  mkdir -p "$UPDATE_DIR"
  if [[ -e "$UPDATE_ARCHIVE" || -e "$UPDATE_ARCHIVE.signature" || -e "$APPCAST_PATH" || -e "$NOTES_PATH" ]]; then
    echo "refusing to overwrite existing Sparkle update files in $UPDATE_DIR" >&2
    exit 1
  fi
  write_release_notes
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$UPDATE_ARCHIVE"
  local sign_update="$SPARKLE_TOOLS_DIR/sign_update"
  local generate_appcast="$SPARKLE_TOOLS_DIR/generate_appcast"
  "$sign_update" "${SPARKLE_SIGNING_ARGS[@]}" "$UPDATE_ARCHIVE" > "$UPDATE_ARCHIVE.signature"
  "$generate_appcast" \
    "${SPARKLE_SIGNING_ARGS[@]}" \
    --download-url-prefix "${LIDPILOT_RELEASE_DOWNLOAD_URL%/*}/" \
    --release-notes-url-prefix "${LIDPILOT_PAGES_URL%/*}/" \
    --link "$LIDPILOT_PAGES_URL" \
    --versions "$BUILD" \
    "$UPDATE_DIR"
  [[ -f "$APPCAST_PATH" ]] || { echo "Sparkle did not generate $APPCAST_PATH" >&2; exit 1; }
  local archive_signature
  local notes_signature
  archive_signature="$(ruby -rrexml/document -e '
    document = REXML::Document.new(File.read(ARGV.fetch(0)))
    enclosure = REXML::XPath.first(document, "//*[local-name()=\"enclosure\"]")
    puts enclosure.attributes["sparkle:edSignature"] if enclosure
  ' "$APPCAST_PATH")"
  notes_signature="$(ruby -rrexml/document -e '
    document = REXML::Document.new(File.read(ARGV.fetch(0)))
    notes = REXML::XPath.first(document, "//*[local-name()=\"releaseNotesLink\"]")
    puts notes.attributes["sparkle:edSignature"] if notes
  ' "$APPCAST_PATH")"
  [[ -n "$archive_signature" ]] || { echo "Sparkle appcast has no archive signature" >&2; exit 1; }
  [[ -n "$notes_signature" ]] || { echo "Sparkle appcast has no release-notes signature" >&2; exit 1; }
  "$sign_update" "${SPARKLE_SIGNING_ARGS[@]}" --verify "$UPDATE_ARCHIVE" "$archive_signature"
  "$sign_update" "${SPARKLE_SIGNING_ARGS[@]}" --verify "$NOTES_PATH" "$notes_signature"
  "$sign_update" "${SPARKLE_SIGNING_ARGS[@]}" --verify "$APPCAST_PATH"
  ruby "$VALIDATOR" \
    --archive "$UPDATE_ARCHIVE" \
    --appcast "$APPCAST_PATH" \
    --notes "$NOTES_PATH" \
    --bundle "$APP_PATH" \
    --feed-url "$LIDPILOT_PAGES_URL" \
    --download-url "$LIDPILOT_RELEASE_DOWNLOAD_URL" \
    --repository "$LIDPILOT_GITHUB_REPOSITORY" \
    --version "$VERSION" \
    --release-label "$RELEASE_LABEL" \
    --channel "$RELEASE_CHANNEL" \
    --build "$BUILD" \
    --hardware-validation "$RELEASE_HARDWARE_VALIDATION" \
    --team "$DEVELOPMENT_TEAM" \
    --sign-tool "$SPARKLE_TOOLS_DIR/sign_update" \
    "${VALIDATOR_SIGNING_ARGS[@]}"
  echo "signed Sparkle update files in $UPDATE_DIR"
}

run_manifest() {
  verify_signed_bundle
  check_regular_file "$DMG_PATH" || { echo "missing stapled DMG: $DMG_PATH" >&2; exit 1; }
  if ! codesign --verify --strict "$DMG_PATH" >/dev/null 2>&1; then
    echo "final DMG is not signed; refuse to hash an unverifiable artifact: $DMG_PATH" >&2
    exit 1
  fi
  if ! xcrun stapler validate "$DMG_PATH" >/dev/null 2>&1; then
    echo "final DMG is not stapled/notarization-valid; refuse to hash it: $DMG_PATH" >&2
    exit 1
  fi
  check_regular_file "$UPDATE_ARCHIVE" || { echo "missing update archive: $UPDATE_ARCHIVE" >&2; exit 1; }
  check_regular_file "$APPCAST_PATH" || { echo "missing appcast: $APPCAST_PATH" >&2; exit 1; }
  check_regular_file "$NOTES_PATH" || { echo "missing signed release notes: $NOTES_PATH" >&2; exit 1; }
  ruby "$VALIDATOR" \
    --archive "$UPDATE_ARCHIVE" \
    --appcast "$APPCAST_PATH" \
    --notes "$NOTES_PATH" \
    --bundle "$APP_PATH" \
    --feed-url "$LIDPILOT_PAGES_URL" \
    --download-url "$LIDPILOT_RELEASE_DOWNLOAD_URL" \
    --repository "$LIDPILOT_GITHUB_REPOSITORY" \
    --version "$VERSION" \
    --release-label "$RELEASE_LABEL" \
    --channel "$RELEASE_CHANNEL" \
    --build "$BUILD" \
    --hardware-validation "$RELEASE_HARDWARE_VALIDATION" \
    --team "$DEVELOPMENT_TEAM" \
    --sign-tool "$SPARKLE_TOOLS_DIR/sign_update" \
    "${VALIDATOR_SIGNING_ARGS[@]}" >/dev/null
  ruby -rjson -rdigest -e '
    version, release_label, channel, hardware_validation, build, feed, download, output, profiling = ARGV.shift(9)
    pairs = ARGV.each_slice(2).to_h
    files = pairs.map do |name, path|
      { "name" => name, "path" => File.basename(path), "sha256" => Digest::SHA256.file(path).hexdigest }
    end
    File.write(output, JSON.pretty_generate(
      "version" => version,
      "releaseLabel" => release_label,
      "channel" => channel,
      "hardwareValidation" => hardware_validation,
      "profilingEnabled" => profiling == "1",
      "build" => build,
      "feedURL" => feed,
      "downloadURL" => download,
      "files" => files
    ) + "\n")
  ' "$VERSION" "$RELEASE_LABEL" "$RELEASE_CHANNEL" "$RELEASE_HARDWARE_VALIDATION" "$BUILD" "$LIDPILOT_PAGES_URL" "$LIDPILOT_RELEASE_DOWNLOAD_URL" "$MANIFEST_PATH" "${LIDPILOT_PROFILE_BUILD:-0}" \
    "dmg" "$DMG_PATH" \
    "update-archive" "$UPDATE_ARCHIVE" \
    "appcast" "$APPCAST_PATH" \
    "release-notes" "$NOTES_PATH"
  mkdir -p "$(dirname "$STATE_FILE")"
  cp "$MANIFEST_PATH" "$STATE_FILE"
  echo "wrote $MANIFEST_PATH"
  echo "publication remains a separate operator action; no remote bytes were uploaded"
}

if [[ "$COMMAND" == "dry-run" ]]; then
  if ! "$ROOT_DIR/scripts/verify.sh"; then
    release_error "static verification failed"
  fi
  preflight dry-run || true
  echo "dry-run complete for LidPilot ${RELEASE_LABEL} (${BUILD}, channel ${RELEASE_CHANNEL}); no signing, notarization, or upload was attempted"
  exit 0
fi

preflight "$COMMAND"
case "$COMMAND" in
  preflight) ;;
  archive) run_archive ;;
  export) run_export ;;
  notarize-app) run_notarize_app ;;
  dmg) run_dmg ;;
  sign-update) run_sign_update ;;
  manifest) run_manifest ;;
  all)
    run_archive
    run_export
    run_notarize_app
    run_dmg
    run_sign_update
    run_manifest
    ;;
esac
