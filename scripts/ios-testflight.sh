#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
destination=export
version_arguments=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --upload) destination=upload; shift ;;
        --version|--bump)
            [[ $# -ge 2 ]] || { echo "$1 requires a value" >&2; exit 2; }
            version_arguments+=("$1" "$2"); shift 2 ;;
        *) echo "usage: scripts/ios-testflight.sh [--upload] [--version X.Y.Z | --bump major|minor|patch]" >&2; exit 2 ;;
    esac
done
authentication=()
if [[ -n "${DICTUM_ASC_KEY_PATH:-}${DICTUM_ASC_KEY_ID:-}${DICTUM_ASC_ISSUER_ID:-}" ]]; then
    : "${DICTUM_ASC_KEY_PATH:?Set the App Store Connect private key file path}"
    : "${DICTUM_ASC_KEY_ID:?Set the App Store Connect key ID}"
    : "${DICTUM_ASC_ISSUER_ID:?Set the App Store Connect issuer ID}"
    [[ -r "$DICTUM_ASC_KEY_PATH" ]] || { echo "API key file is not readable" >&2; exit 2; }
    authentication=(-authenticationKeyPath "$DICTUM_ASC_KEY_PATH" \
        -authenticationKeyID "$DICTUM_ASC_KEY_ID" -authenticationKeyIssuerID "$DICTUM_ASC_ISSUER_ID")
fi
output="$ROOT/build/ios-testflight"
mkdir -p "$output"
export_options="$output/ExportOptions.plist"
python3 - "$export_options" <<'PY'
import plistlib
import sys

with open("iOS/Resources/TestFlightExportOptions.plist", "rb") as file:
    options = plistlib.load(file)
options["destination"] = "export"
with open(sys.argv[1], "wb") as file:
    plistlib.dump(options, file)
PY
python3 scripts/version.py ${version_arguments[@]+"${version_arguments[@]}"}
xcodegen generate --quiet
xcodebuild archive -project Dictum.xcodeproj -scheme DictumIOS -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$output/Dictum.xcarchive" \
    -derivedDataPath build/ios-distribution -clonedSourcePackagesDirPath build/ios/SourcePackages \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration ${authentication[@]+"${authentication[@]}"}
xcodebuild -exportArchive -archivePath "$output/Dictum.xcarchive" \
    -exportPath "$output/export" -exportOptionsPlist "$export_options" -allowProvisioningUpdates ${authentication[@]+"${authentication[@]}"}
python3 scripts/validate-ios-export.py "$output/export/Dictum.ipa"
if [[ "$destination" == upload ]]; then
    python3 - "$export_options" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as file:
    options = plistlib.load(file)
options["destination"] = "upload"
with open(sys.argv[1], "wb") as file:
    plistlib.dump(options, file)
PY
    xcodebuild -exportArchive -archivePath "$output/Dictum.xcarchive" \
        -exportPath "$output/upload" -exportOptionsPlist "$export_options" -allowProvisioningUpdates ${authentication[@]+"${authentication[@]}"}
fi
