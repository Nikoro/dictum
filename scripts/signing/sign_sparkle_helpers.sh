#!/usr/bin/env bash

set -euo pipefail

[[ "${CODE_SIGNING_ALLOWED:-YES}" == "NO" || -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]] && exit 0

framework="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/Sparkle.framework"
sparkle="$framework/Versions/B"
[[ -d "$sparkle" ]] || exit 0

# shellcheck disable=SC2086
sign() { codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --options runtime ${OTHER_CODE_SIGN_FLAGS:-} "$@"; }

sign "$sparkle/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$sparkle/XPCServices/Downloader.xpc"
sign "$sparkle/Autoupdate"
sign "$sparkle/Updater.app"
sign "$framework"
