#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="$ROOT/.tools/commit_gate"
revision="$(cat "$ROOT/scripts/quality/commit_gate.ref")"
cd "$ROOT"
while IFS= read -r variable; do
    unset "$variable"
done < <(git rev-parse --local-env-vars)

if [[ ! -d "$GATE/.git" ]]; then
    git clone git@github.com:Nikoro/commit_gate.git "$GATE"
fi
if [[ -n "$(git -C "$GATE" status --porcelain)" ]]; then
    echo "commit_gate has local changes; develop fixes in a separate clone before updating the installed tool." >&2
    exit 2
fi
if ! git -C "$GATE" cat-file -e "$revision^{commit}" 2>/dev/null; then
    git -C "$GATE" fetch origin "$revision"
fi
git -C "$GATE" checkout --detach "$revision"
