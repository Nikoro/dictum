#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="$ROOT/.tools/commit_gate"
revision="$(cat "$ROOT/scripts/quality/commit_gate.ref")"
cd "$ROOT"

if [[ ! -f "$GATE/__main__.py" ]]; then
    "$ROOT/scripts/quality/install_commit_gate.sh"
fi
gate_git() (
    while IFS= read -r variable; do
        unset "$variable"
    done < <(git rev-parse --local-env-vars)
    git -C "$GATE" "$@"
)
installed_revision="$(gate_git rev-parse HEAD)"
gate_changes="$(gate_git status --porcelain)"
if [[ "$installed_revision" != "$revision" || -n "$gate_changes" ]]; then
    echo "commit_gate must match its clean pinned revision; run scripts/quality/install_commit_gate.sh." >&2
    exit 2
fi
for python in /opt/homebrew/bin/python3 python3 python3.15 python3.14 python3.13 python3.12 python3.11; do
    if command -v "$python" >/dev/null 2>&1 && "$python" -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
        exec "$python" "$GATE" "$@"
    fi
done
echo "commit_gate needs Python 3.11 or newer." >&2
exit 2
