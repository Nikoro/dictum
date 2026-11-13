#!/usr/bin/env bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
chmod +x "$ROOT/scripts/hooks/"* "$ROOT/scripts/quality/"*.sh "$ROOT/scripts/quality/"*.py "$ROOT/scripts/test.sh"
"$ROOT/scripts/quality/install_commit_gate.sh"
git -C "$ROOT" config core.hooksPath scripts/hooks
echo "Installed git hooks: core.hooksPath = scripts/hooks"
