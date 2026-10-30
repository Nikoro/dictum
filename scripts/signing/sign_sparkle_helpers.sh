#!/usr/bin/env bash
# Xcode signs the embedded Sparkle.framework but not the helper tools nested inside it, which
# keep Sparkle's own signature and fail notarization. Re-signs them, innermost first, with our
# identity; Xcode then seals the app around them. Order and flags follow Sparkle's docs.

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
