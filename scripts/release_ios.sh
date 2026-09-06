#!/bin/bash
set -euo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACTS="$ROOT/artifacts"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ARTIFACTS/HuJu.xcarchive}"
TEAM_ID="JAN597TBVS"
BUNDLE_ID="com.zhangjingwei.huju"
ACTION="${1:-all}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
EXPORT_PATH="${EXPORT_PATH:-$ARTIFACTS/AppStore-$TIMESTAMP}"
DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
XCODEBUILD="$DEVELOPER_DIR/usr/bin/xcodebuild"

usage() {
  cat <<'EOF'
Usage: ./scripts/release_ios.sh [preflight|archive|export|upload|all]

  preflight  Check local signing prerequisites.
  archive    Create and validate a signed App Store archive.
  export     Export an existing archive as an IPA.
  upload     Upload an existing archive to App Store Connect.
  all        Archive, validate, and export an IPA (default).
EOF
}

require_file() {
  if [[ ! -e "$1" ]]; then
    printf 'Missing required file: %s\n' "$1" >&2
    exit 1
  fi
}

validate_screenshots() {
  local screenshot
  local width
  local height
  local has_alpha
  local count=0

  while IFS= read -r screenshot; do
    width="$(sips -g pixelWidth "$screenshot" | awk '/pixelWidth/ { print $2 }')"
    height="$(sips -g pixelHeight "$screenshot" | awk '/pixelHeight/ { print $2 }')"
    has_alpha="$(sips -g hasAlpha "$screenshot" | awk '/hasAlpha/ { print $2 }')"

    if [[ "$width" != "1290" || "$height" != "2796" ]]; then
      printf 'Invalid screenshot dimensions for %s: %sx%s.\n' \
        "$screenshot" "$width" "$height" >&2
      exit 1
    fi
    if [[ "$has_alpha" != "no" ]]; then
      printf 'Screenshot contains an alpha channel: %s\n' "$screenshot" >&2
      exit 1
    fi
    count=$((count + 1))
  done < <(
    find "$ROOT/AppStore/screenshots/zh-Hans" \
      -maxdepth 1 -type f -name '*.png' -print | sort
  )

  if [[ "$count" -ne 7 ]]; then
    printf 'Expected 7 App Store screenshots, found %s.\n' "$count" >&2
    exit 1
  fi
}

preflight() {
  require_file "$XCODEBUILD"
  require_file "$ROOT/HuJu.xcodeproj"
  require_file "$ROOT/HuJu/HuJu.entitlements"
  require_file "$ROOT/AppStore/ExportOptions.plist"
  require_file "$ROOT/AppStore/UploadOptions.plist"
  validate_screenshots

  if ! security find-identity -v -p codesigning \
    | grep -Fq "Apple Distribution:"; then
    printf 'No valid Apple Distribution signing identity was found.\n' >&2
    exit 1
  fi

  if ! grep -Fq "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;" \
    "$ROOT/HuJu.xcodeproj/project.pbxproj"; then
    printf 'Expected bundle identifier %s is not configured.\n' "$BUNDLE_ID" >&2
    exit 1
  fi

  if ! grep -Fq "DEVELOPMENT_TEAM = $TEAM_ID;" \
    "$ROOT/HuJu.xcodeproj/project.pbxproj"; then
    printf 'Expected development team %s is not configured.\n' "$TEAM_ID" >&2
    exit 1
  fi

  "$XCODEBUILD" -version
  printf 'Signing preflight passed for %s (%s).\n' "$BUNDLE_ID" "$TEAM_ID"
}

validate_archive() {
  local app_path="$ARCHIVE_PATH/Products/Applications/HuJu.app"
  local profile_path="$app_path/embedded.mobileprovision"
  local profile_plist
  local actual_bundle_id
  local profile_app_id
  local apple_sign_in

  require_file "$ARCHIVE_PATH/Info.plist"
  require_file "$app_path/Info.plist"
  require_file "$profile_path"

  actual_bundle_id="$(plutil -extract CFBundleIdentifier raw -o - "$app_path/Info.plist")"
  if [[ "$actual_bundle_id" != "$BUNDLE_ID" ]]; then
    printf 'Archive bundle identifier is %s, expected %s.\n' \
      "$actual_bundle_id" "$BUNDLE_ID" >&2
    exit 1
  fi

  codesign --verify --deep --strict --verbose=2 "$app_path"

  profile_plist="$(mktemp /tmp/huju-profile.XXXXXX.plist)"
  security cms -D -i "$profile_path" > "$profile_plist"
  profile_app_id="$(
    plutil -extract Entitlements.application-identifier raw -o - "$profile_plist"
  )"
  apple_sign_in="$(
    plutil -extract Entitlements.com.apple.developer.applesignin.0 raw \
      -o - "$profile_plist" 2>/dev/null || true
  )"
  rm -f "$profile_plist"

  if [[ "$profile_app_id" != "$TEAM_ID.$BUNDLE_ID" ]]; then
    printf 'Provisioning profile app identifier is %s, expected %s.%s.\n' \
      "$profile_app_id" "$TEAM_ID" "$BUNDLE_ID" >&2
    exit 1
  fi

  if [[ "$apple_sign_in" != "Default" ]]; then
    printf 'Provisioning profile does not include Sign in with Apple.\n' >&2
    exit 1
  fi

  printf 'Validated signed archive: %s\n' "$ARCHIVE_PATH"
}

archive_app() {
  mkdir -p "$ARTIFACTS"
  if ! "$XCODEBUILD" \
    -project "$ROOT/HuJu.xcodeproj" \
    -scheme HuJu \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    clean archive 2>&1 | tee "$ARTIFACTS/archive.log"; then
    cat >&2 <<'EOF'
Archive failed. In Xcode, open Settings > Accounts and sign in again, then
ensure com.zhangjingwei.huju has the Sign in with Apple capability enabled.
EOF
    exit 1
  fi
  validate_archive
}

export_ipa() {
  validate_archive
  if ! "$XCODEBUILD" \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$ROOT/AppStore/ExportOptions.plist" \
    -allowProvisioningUpdates 2>&1 | tee "$ARTIFACTS/export.log"; then
    printf 'IPA export failed. Review %s/export.log.\n' "$ARTIFACTS" >&2
    exit 1
  fi

  local ipa_path
  ipa_path="$(find "$EXPORT_PATH" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
  if [[ -z "$ipa_path" ]]; then
    printf 'Export completed without producing an IPA in %s.\n' \
      "$EXPORT_PATH" >&2
    exit 1
  fi
  printf 'Exported IPA: %s\n' "$ipa_path"
}

upload_archive() {
  validate_archive
  if ! "$XCODEBUILD" \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$ROOT/AppStore/UploadOptions.plist" \
    -allowProvisioningUpdates 2>&1 | tee "$ARTIFACTS/upload.log"; then
    printf 'Upload failed. Review %s/upload.log.\n' "$ARTIFACTS" >&2
    exit 1
  fi
  printf 'Uploaded archive to App Store Connect.\n'
}

case "$ACTION" in
  preflight)
    preflight
    ;;
  archive)
    preflight
    archive_app
    ;;
  export)
    preflight
    export_ipa
    ;;
  upload)
    preflight
    upload_archive
    ;;
  all)
    preflight
    archive_app
    export_ipa
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
