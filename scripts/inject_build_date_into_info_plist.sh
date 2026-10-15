#!/usr/bin/env bash
set -euo pipefail
APP_BUNDLE="${FULL_PRODUCT_NAME:-${PRODUCT_NAME:-AltTabDev}.app}"
PLIST="${BUILT_PRODUCTS_DIR}/${APP_BUNDLE}/Contents/Info.plist"
if [ ! -f "$PLIST" ]; then
  echo "warning: Info.plist not found at $PLIST (PRODUCT_NAME=${PRODUCT_NAME:-})"
  exit 0
fi

set_or_add_string() {
  local key="$1" value="$2"
  if /usr/libexec/PlistBuddy -c "Print :$key" "$PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :$key \"$value\"" "$PLIST"
  else
    /usr/libexec/PlistBuddy -c "Add :$key string \"$value\"" "$PLIST"
  fi
}

BUILD_DATE=$(date +"%Y-%m-%d %H:%M")
set_or_add_string AltTabBuildDate "$BUILD_DATE"

GIT_HASH="unknown"
if command -v git >/dev/null 2>&1; then
  root="${SRCROOT:-}"
  if [ -n "$root" ] && git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_HASH=$(git -C "$root" rev-parse --short=7 HEAD 2>/dev/null || echo unknown)
    if ! git -C "$root" diff --quiet 2>/dev/null || ! git -C "$root" diff --cached --quiet 2>/dev/null; then
      GIT_HASH="${GIT_HASH}-dirty"
    fi
  fi
fi
set_or_add_string AltTabGitHash "$GIT_HASH"
