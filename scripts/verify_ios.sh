#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT/DerivedData"
ARTIFACTS="$ROOT/artifacts"
DEVICE_ID="${DEVICE_ID:-2740D087-F6B2-4352-A330-C86ACD73D71D}"
BUNDLE_ID="com.zhangjingwei.huju"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/HuJu.app"

mkdir -p "$ARTIFACTS"
cd "$ROOT"

xcodebuild \
  -project HuJu.xcodeproj \
  -scheme HuJu \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build | tee "$ARTIFACTS/build.log"

xcrun simctl shutdown all 2>/dev/null || true
xcrun simctl boot "$DEVICE_ID"
open -a Simulator
sleep 20

xcodebuild \
  -project HuJu.xcodeproj \
  -scheme HuJu \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  test | tee "$ARTIFACTS/test.log"

xcrun simctl uninstall "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" -showLogin
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot "$ARTIFACTS/login.png"

xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" -uiTestAuthenticated -loadSampleData
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot "$ARTIFACTS/home.png"

xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" -uiTestAuthenticated -loadSampleData -showMap
sleep 5
xcrun simctl io "$DEVICE_ID" screenshot "$ARTIFACTS/map.png"

xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" -uiTestAuthenticated -loadSampleData -showAI
sleep 3
xcrun simctl io "$DEVICE_ID" screenshot "$ARTIFACTS/ai.png"

printf 'verification=passed\n'
