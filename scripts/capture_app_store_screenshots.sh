#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT/DerivedData-AppStore"
OUTPUT="$ROOT/AppStore/screenshots/zh-Hans"
DEVICE_ID="${DEVICE_ID:-2740D087-F6B2-4352-A330-C86ACD73D71D}"
BUNDLE_ID="com.zhangjingwei.huju"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/HuJu.app"

mkdir -p "$OUTPUT"
cd "$ROOT"

xcodebuild \
  -project HuJu.xcodeproj \
  -scheme HuJu \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b
open -a Simulator
xcrun simctl ui "$DEVICE_ID" appearance light
xcrun simctl status_bar "$DEVICE_ID" override \
  --time "9:41" \
  --operatorName "" \
  --wifiBars 3 \
  --cellularBars 4 \
  --batteryLevel 100 \
  --batteryState charged

xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

capture() {
  local output="$1"
  local delay="$2"
  shift 2
  xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" "$@"
  sleep "$delay"
  xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT/$output"
}

capture "01-empty-workspace.png" 3
capture "02-optional-login.png" 3 -showLogin
capture "03-home-demo.png" 3 -uiTestAuthenticated -loadSampleData
capture "04-map-demo.png" 5 -uiTestAuthenticated -loadSampleData -showMap
capture "05-journal-demo.png" 3 -uiTestAuthenticated -loadSampleData -showJournal
capture "06-decision-demo.png" 3 -uiTestAuthenticated -loadSampleData -showAI
capture "07-market-demo.png" 3 -uiTestAuthenticated -loadSampleData -showRadar

xcrun simctl status_bar "$DEVICE_ID" clear
printf 'screenshots=%s\n' "$OUTPUT"
