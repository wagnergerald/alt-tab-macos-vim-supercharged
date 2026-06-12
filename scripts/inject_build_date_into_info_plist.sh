#!/usr/bin/env bash
set -euo pipefail
APP_BUNDLE="${FULL_PRODUCT_NAME:-${PRODUCT_NAME}.app}"
PLIST="${BUILT_PRODUCTS_DIR}/${APP_BUNDLE}/Contents/Info.plist"
if [ ! -f "$PLIST" ]; then
  echo "warning: Info.plist not found at $PLIST (PRODUCT_NAME=${PRODUCT_NAME:-})"
  exit 0
fi
BUILD_DATE=$(date +"%Y-%m-%d %H:%M")
if /usr/libexec/PlistBuddy -c "Print :AltTabBuildDate" "$PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :AltTabBuildDate \"$BUILD_DATE\"" "$PLIST"
else
  /usr/libexec/PlistBuddy -c "Add :AltTabBuildDate string \"$BUILD_DATE\"" "$PLIST"
fi
