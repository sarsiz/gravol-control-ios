#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_FILE="${1:-$ROOT_DIR/simulator-volume-log-iphone.txt}"
BUNDLE_ID="${BUNDLE_ID:-com.sarsiz.GraVolControl}"
DEVICE_ID="${DEVICE_ID:-booted}"

DATA_CONTAINER="$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data 2>/dev/null || true)"
if [[ -z "$DATA_CONTAINER" ]]; then
  echo "Could not find app data container for '$BUNDLE_ID' on simulator '$DEVICE_ID'."
  echo "Run the app once on Simulator, then run this script again."
  exit 1
fi

NEW_LOG_FILE="$DATA_CONTAINER/Documents/GraVolControl/Logs/simulator-volume-log-iphone.txt"
APP_SUPPORT_LOG_FILE="$DATA_CONTAINER/Library/Application Support/simulator-volume-log-iphone.txt"
LEGACY_LOG_FILE="$DATA_CONTAINER/Library/Application Support/volume-diagnostics.log"
APP_GROUP_PLIST="$DATA_CONTAINER/Library/Preferences/group.com.sarsiz.GraVolControl.plist"

{
  echo "GraVol Simulator Volume Diagnostics"
  echo "Generated: $(date)"
  echo "Bundle: $BUNDLE_ID"
  echo "Data Container: $DATA_CONTAINER"
  echo
  if [[ -f "$NEW_LOG_FILE" ]]; then
    echo "=== File Log (Documents/GraVolControl/Logs/simulator-volume-log-iphone.txt) ==="
    cat "$NEW_LOG_FILE"
    echo
  elif [[ -f "$APP_SUPPORT_LOG_FILE" ]]; then
    echo "=== File Log (Application Support/simulator-volume-log-iphone.txt) ==="
    cat "$APP_SUPPORT_LOG_FILE"
    echo
  elif [[ -f "$LEGACY_LOG_FILE" ]]; then
    echo "=== File Log (Application Support/volume-diagnostics.log) ==="
    cat "$LEGACY_LOG_FILE"
    echo
  else
    echo "No file log found at:"
    echo "$NEW_LOG_FILE"
    echo "$APP_SUPPORT_LOG_FILE"
    echo "$LEGACY_LOG_FILE"
    echo
  fi

  if [[ -f "$APP_GROUP_PLIST" ]]; then
    echo "=== App Group Stored Log (gravol_volume_diagnostics_log) ==="
    defaults read "$APP_GROUP_PLIST" gravol_volume_diagnostics_log 2>/dev/null || echo "No gravol_volume_diagnostics_log key found."
    echo
  else
    echo "No App Group plist found at: $APP_GROUP_PLIST"
    echo
  fi
} > "$OUT_FILE"

echo "Exported logs to:"
echo "$OUT_FILE"
