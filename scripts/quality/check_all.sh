#!/usr/bin/env bash
# Runs every pre-commit gate over the whole repository instead of the staged files.

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

files=()
while IFS= read -r file; do
    files+=("$file")
done < <(git ls-files --cached --others --exclude-standard '*.swift' | grep -vE '^(\.agents|build|website)/')

status=0
swiftlint lint --strict --quiet || status=1
swiftformat --lint --quiet . || status=1
scripts/quality/check_nesting.py "${files[@]}" || status=1
scripts/quality/check_comments.py "${files[@]}" || status=1
scripts/quality/lizard.sh "${files[@]}" || status=1
scripts/quality/check_strings.py || status=1

[[ $status -eq 0 ]] && echo "check: all gates passed"
exit "$status"
