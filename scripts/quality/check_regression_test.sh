#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 || ! -f "$1" ]]; then
    echo "usage: $0 <commit-msg-file>" >&2
    exit 2
fi

ROOT="$(git rev-parse --show-toplevel)"
subject="$(grep -vE '^\s*#' "$1" | sed '/^\s*$/d' | head -n1 | tr '[:upper:]' '[:lower:]' || true)"

case "$subject" in
    fix:* | fix\(*\):* | fix!:* | fix\(*\)!:* | bug:* | bug\(*\):* | hotfix:* | hotfix\(*\):* | \
        napraw:* | napraw\(*\):* | naprawia:* | naprawia\(*\):*) ;;
    *) exit 0 ;;
esac

app_swift=()
tests=()
while IFS= read -r file; do
    case "$file" in
        DictumTests/*Tests.swift) tests+=("$file") ;;
        DictumTests/* | .agents/* | build/* | website/* | scripts/*) ;;
        *.swift) app_swift+=("$file") ;;
    esac
done < <(git diff --cached --name-only --diff-filter=ACMR)

if [[ ${#app_swift[@]} -eq 0 ]]; then
    echo "commit-msg: fix without app Swift changes, regression test gate skipped."
    exit 0
fi

if [[ ${#tests[@]} -eq 0 ]]; then
    {
        echo "commit-msg: BLOCKED, a fix commit needs a regression test."
        echo "Add a failing test that reproduces the bug (red), fix it (green), stage both. Mirror location:"
        for file in "${app_swift[@]}"; do
            echo "  $file → DictumTests/${file%.swift}Tests.swift"
        done
        echo "Not a fix? Use refactor:, chore: or feat: instead."
    } >&2
    exit 1
fi

echo "commit-msg: regression test(s): ${tests[*]}"
"$ROOT/scripts/test.sh"
