#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "0.0.0+gerald.0.unknown"; exit 0; }
cd "$root"
git describe --tags --dirty --always 2>/dev/null || echo "0.0.0+gerald.0.$(git rev-parse --short=7 HEAD 2>/dev/null || echo unknown)"
