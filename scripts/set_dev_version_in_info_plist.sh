#!/usr/bin/env bash
set -euo pipefail
[ "${CONFIGURATION:-}" = "Debug" ] || exit 0
/bin/bash "${SRCROOT}/scripts/write_dev_version_xcconfig.sh"
PLIST="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}/Contents/Info.plist"
if [ ! -f "$PLIST" ]; then
  echo "warning: Info.plist not found at $PLIST"
  exit 0
fi
VERSION=$(/bin/bash "${SRCROOT}/scripts/compute_dev_version.sh")
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion \"$VERSION\"" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString \"$VERSION\"" "$PLIST"
BUILD_DATE=$(date +"%Y-%m-%d %H:%M")
if /usr/libexec/PlistBuddy -c "Print :AltTabBuildDate" "$PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :AltTabBuildDate \"$BUILD_DATE\"" "$PLIST"
else
  /usr/libexec/PlistBuddy -c "Add :AltTabBuildDate string \"$BUILD_DATE\"" "$PLIST"
fi
