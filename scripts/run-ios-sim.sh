#!/usr/bin/env bash
# Builds Water Tally for the iOS Simulator, installs it and launches it.
#   scripts/run-ios-sim.sh                      # default device
#   DEVICE_NAME="iPhone 17 Pro" scripts/run-ios-sim.sh
#   scripts/run-ios-sim.sh -demoData -showScreen trends   # extra args go to the app (DEBUG hooks)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$REPO_DIR/WaterTally.xcodeproj"
SCHEME="WaterTally"
DERIVED_DATA="${DERIVED_DATA:-${TMPDIR:-/tmp}/WaterTallyDerivedData}"
APP_BUNDLE_ID="me.ryham.WaterTally"
DEVICE_NAME="${DEVICE_NAME:-iPhone 17 Pro}"

fail() { echo "[ERROR] $1" >&2; exit 1; }

[[ -d "$PROJECT" ]] || fail "Project not found at $PROJECT"
xcrun --find simctl >/dev/null 2>&1 || fail "simctl not found. Open Xcode once so it can finish installing components."

pick_device() {
  local line
  line="$(xcrun simctl list devices available | grep -E "^[[:space:]]+${DEVICE_NAME} \(" | head -n1 || true)"
  [[ -z "$line" ]] && line="$(xcrun simctl list devices available | grep -E "^[[:space:]]+iPhone" | head -n1 || true)"
  [[ -n "$line" ]] || fail "No available iPhone simulators. Install a runtime in Xcode > Settings > Platforms."
  echo "$line" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

UDID="$(pick_device)"
echo "[INFO] Using simulator $UDID"
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
open -a Simulator >/dev/null 2>&1 || true

echo "[INFO] Building..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO build -quiet

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/WaterTally.app"
[[ -d "$APP_PATH" ]] || fail "Built app not found at $APP_PATH"

echo "[INFO] Installing and launching..."
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl terminate "$UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl launch "$UDID" "$APP_BUNDLE_ID" "$@"
echo "[DONE] Water Tally running on $UDID"
