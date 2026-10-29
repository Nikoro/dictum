#!/usr/bin/env bash
# Points git at the versioned hooks in scripts/hooks. Idempotent; run once per clone.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
chmod +x "$ROOT/scripts/hooks/pre-commit" "$ROOT/scripts/quality/"*
git -C "$ROOT" config core.hooksPath scripts/hooks
echo "Installed git hooks: core.hooksPath = scripts/hooks"
