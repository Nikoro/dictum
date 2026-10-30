#!/usr/bin/env bash
# commit-msg gate: a fix commit must ship a regression test, and the tests must pass.
#
# A fix commit is one whose subject starts with fix:, fix(scope):, bug:, hotfix: or the Polish
# napraw:/naprawia: (optional `!`). When it stages app Swift code, it must also add or modify a
# test in the mirror location of the fixed file:
#
#     Transcription/WhisperModelStorage.swift → DictumTests/Transcription/WhisperModelStorageTests.swift
#
# Existing file: add the case to it. Missing file: create it. Write the test first and watch it
# fail (red), then fix the code (green), then refactor. The gate then runs the whole suite.
#
# A fix that stages no app Swift code (website, workflow, scripts, strings) is skipped: there is
# no Swift test that could reproduce it, and an unrelated one would only appease the hook.

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
