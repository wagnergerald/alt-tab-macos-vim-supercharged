#!/bin/bash

bash scripts/write_dev_version_xcconfig.sh
VERSION=$(bash scripts/compute_dev_version.sh)

xcodebuild \
  -project alt-tab-macos.xcodeproj \
  -scheme Debug \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CURRENT_PROJECT_VERSION="$VERSION"
