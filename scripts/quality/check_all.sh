#!/usr/bin/env bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
if command -v mise >/dev/null 2>&1; then
    eval "$(mise env -s bash 2>/dev/null)"
fi

files=()
while IFS= read -r file; do
    [[ -f "$file" ]] && files+=("$file")
done < <(git ls-files --cached --others --exclude-standard '*.swift' | grep -vE '^(\.agents|build|website)/')

status=0
swiftlint lint --strict --quiet || status=1
swiftformat --lint --quiet . || status=1
scripts/quality/check_nesting.py "${files[@]}" || status=1
scripts/quality/commit_gate.sh check || status=1
scripts/quality/check_log_privacy.py "${files[@]}" || status=1
scripts/quality/lizard.sh "${files[@]}" || status=1
scripts/quality/check_strings.py || status=1

[[ $status -eq 0 ]] && echo "check: all gates passed"
exit "$status"
