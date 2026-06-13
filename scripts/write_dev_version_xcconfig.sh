#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
out="$root/config/generated-dev-version.xcconfig"
version=$(/bin/bash "$root/scripts/compute_dev_version.sh")
printf 'CURRENT_PROJECT_VERSION = "%s"\n' "$version" > "$out"
