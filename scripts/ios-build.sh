#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
xcodegen generate --quiet
if [[ "${1:-}" == "--device" ]]; then
    xcodebuild -project Dictum.xcodeproj -scheme DictumIOS -configuration Debug \
        -destination 'generic/platform=iOS' -derivedDataPath build/ios-device -allowProvisioningUpdates build
else
    xcodebuild -project Dictum.xcodeproj -scheme DictumIOS -configuration Debug \
        -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ios build
fi
