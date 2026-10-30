#!/usr/bin/env bash
# Runs the DictumTests unit tests; prints only the failures. Usage: scripts/test.sh

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

xcodegen generate --quiet
log="$(mktemp -t dictum-test)"
if ! xcodebuild test -project Dictum.xcodeproj -scheme Dictum -destination 'platform=macOS' >"$log" 2>&1; then
    grep -E "✘|error:" "$log" | sort -u >&2 || true
    echo "test: FAILED, full log at $log" >&2
    exit 1
fi
grep -E "Test run with" "$log" | tail -1
