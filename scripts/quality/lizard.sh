#!/usr/bin/env bash
# Cognitive complexity gate (SonarSource metric, via Lizard) for the given Swift files.
# SwiftLint covers cyclomatic complexity but has no cognitive complexity rule; Lizard's own
# nesting-depth metric is not used because it counts every `case` of a Swift `switch` as a level.
#
# Lizard is not in Homebrew (`brew install lizard` is an unrelated compressor), so it is
# installed on first use into a project-local venv at .tools/lizard, pinned below.
#
# Usage: scripts/quality/lizard.sh FILE...

set -euo pipefail

LIZARD_VERSION="1.24.3"
MAX_COGNITIVE_COMPLEXITY=10

ROOT="$(git rev-parse --show-toplevel)"
VENV="$ROOT/.tools/lizard"

if [[ ! -x "$VENV/bin/lizard" ]] || ! "$VENV/bin/lizard" --version 2>/dev/null | grep -qx "$LIZARD_VERSION"; then
    echo "Installing lizard $LIZARD_VERSION into .tools/lizard..." >&2
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet --disable-pip-version-check "lizard==$LIZARD_VERSION"
fi

[[ $# -gt 0 ]] || exit 0

# -w prints only functions over a threshold and exits non-zero if there are any. The default
# CCN and length thresholds are raised out of the way; SwiftLint already enforces both.
"$VENV/bin/lizard" --languages swift --warnings_only -Ecognitive \
    -T "cognitive_complexity=$MAX_COGNITIVE_COMPLEXITY" -T cyclomatic_complexity=1000 -T length=10000 \
    "$@"
