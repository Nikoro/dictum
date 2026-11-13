#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
if [[ $# -ne 1 ]]; then
    echo "usage: scripts/ios-test.sh <iPhone UDID>" >&2
    exit 2
fi
xcodegen generate --quiet
xcodebuild test -project Dictum.xcodeproj -scheme DictumIOS \
    -destination "platform=iOS,id=$1" -derivedDataPath build/ios-device \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration
