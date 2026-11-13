#!/usr/bin/env bash

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

"$VENV/bin/lizard" --languages swift --warnings_only -Ecognitive \
    -T "cognitive_complexity=$MAX_COGNITIVE_COMPLEXITY" -T cyclomatic_complexity=1000 -T length=10000 \
    "$@"
