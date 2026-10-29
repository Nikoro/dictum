#!/usr/bin/env bash
# Kills the running Dictum, builds Debug, launches the fresh build and confirms it stays up.
# Usage: scripts/run.sh [--no-launch]

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

pkill -x Dictum || true
xcodegen generate --quiet
build_log="$(mktemp -t dictum-build)"
if ! xcodebuild -project Dictum.xcodeproj -scheme Dictum -configuration Debug build >"$build_log" 2>&1; then
    grep -E "error:" "$build_log" | sort -u >&2
    echo "run: build failed, full log at $build_log" >&2
    exit 1
fi
echo "run: build succeeded"
[[ "${1:-}" == "--no-launch" ]] && exit 0

products_dir="$(xcodebuild -project Dictum.xcodeproj -scheme Dictum -configuration Debug -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')"
open -n "$products_dir/Dictum.app"
sleep 3
if ! pgrep -x Dictum >/dev/null; then
    echo "run: Dictum exited right after launch; see ~/Library/Logs/Dictum/dictum.log" >&2
    exit 1
fi
echo "run: Dictum is running ($products_dir/Dictum.app)"
