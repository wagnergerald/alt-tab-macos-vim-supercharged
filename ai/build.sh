#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

bash scripts/write_dev_version_xcconfig.sh
VERSION=$(bash scripts/compute_dev_version.sh)

xcodebuild \
  -project alt-tab-macos.xcodeproj \
  -scheme Debug \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CURRENT_PROJECT_VERSION="$VERSION"

PRODUCT="$PWD/DerivedData/Build/Products/Debug/AltTabDev.app"
INSTALL="/Applications/AltTabDev.app"

if [[ ! -d "$PRODUCT" ]]; then
  echo "error: built app not found at $PRODUCT" >&2
  exit 1
fi

# Quit any running AltTabDev before replacing the Applications install.
if pgrep -xq AltTabDev; then
  echo "Quitting AltTabDev…"
  osascript -e 'tell application "AltTabDev" to quit' >/dev/null 2>&1 || true
  for _ in $(seq 1 50); do
    pgrep -xq AltTabDev || break
    sleep 0.1
  done
  if pgrep -xq AltTabDev; then
    killall AltTabDev 2>/dev/null || true
    sleep 0.3
  fi
fi

# Stable Applications entry so LaunchServices/TCC keep the same path across rebuilds.
rm -rf "$INSTALL"
ln -sfn "$PRODUCT" "$INSTALL"
echo "Linked $INSTALL -> $PRODUCT"

echo "Launching AltTabDev…"
open -n -a "$INSTALL"
