#!/usr/bin/env bash
# Builds a DEBUG simulator build and captures the App Store screenshots with sample data:
#   6.5" iPhone (1284x2778, iPhone 14 Plus)   ->  screenshots/iphone-6.5/
#   13" iPad    (2064x2752, iPad Pro 13-inch) ->  screenshots/ipad-13/
# Usage (from the repo root):  tools/app-store-screenshots.sh
# Creates the simulators if they don't exist and runs them one at a time. The status bar is set to
# 9:41 with full battery.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-${TMPDIR:-/tmp}/WaterTallyScreenshotsDD}"
BUNDLE_ID="me.ryham.WaterTally"
OUT="$REPO_DIR/screenshots"
RUNTIME="$(xcrun simctl list runtimes available | grep -E '^iOS' | tail -1 | sed -E 's/.* - (com\.apple\.[^ ]+).*/\1/')"

# name|device type|output folder
DEVICES=(
  "WT Screens iPhone 6.5|com.apple.CoreSimulator.SimDeviceType.iPhone-14-Plus|iphone-6.5"
  "WT Screens iPad 13|com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB|ipad-13"
)

# file name|launch arguments (always with -demoData)
SHOTS=(
  "1-today|-simulateLog 8,16,8,16"
  "2-trends|-showScreen trends"
  "3-calendar|-showScreen calendar"
  "4-history|-daysAgo 1 -showScreen history"
  "5-buttons|-showScreen edit"
  "6-weekly|-showScreen weekly"
)

echo "[INFO] Building..."
xcodebuild -project "$REPO_DIR/WaterTally.xcodeproj" -scheme WaterTally -configuration Debug \
  -sdk iphonesimulator -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO build -quiet
APP="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/WaterTally.app"

for device in "${DEVICES[@]}"; do
  IFS='|' read -r NAME TYPE FOLDER <<< "$device"
  UDID="$(xcrun simctl list devices available | grep -F "$NAME (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)"
  [[ -n "$UDID" ]] || UDID="$(xcrun simctl create "$NAME" "$TYPE" "$RUNTIME")"
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3
  xcrun simctl install "$UDID" "$APP"
  mkdir -p "$OUT/$FOLDER"

  for shot in "${SHOTS[@]}"; do
    IFS='|' read -r FILE ARGS <<< "$shot"
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    # shellcheck disable=SC2086
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -demoData $ARGS >/dev/null
    sleep 5
    xcrun simctl io "$UDID" screenshot --type=png "$OUT/$FOLDER/$FILE.png" >/dev/null 2>&1
    echo "[INFO] $FOLDER/$FILE.png"
  done
  # One simulator at a time: shut this one down before the next boots.
  xcrun simctl shutdown "$UDID"
done
echo "[DONE] Screenshots are in $OUT"
