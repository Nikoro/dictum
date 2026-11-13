# Quality gates

- Never bypass the pre-commit or commit-msg hook with `--no-verify`.
- A `fix:` commit that stages app Swift code must also stage a test in the mirror location
  (`Shared/Keyboard/Foo.swift` → `DictumTests/Keyboard/FooTests.swift`, extend it if it exists),
  and the suite must pass (`scripts/quality/check_regression_test.sh`). The test must fail before
  the fix; one that passes either way does not count. A layout-only fix gets `refactor:` instead of
  an invented test.
- Tests use Swift Testing and run hosted in the app; `DictumApp` skips its startup under XCTest.
  Logic that touches the file system takes its directories as parameters so tests use temp folders.
- `scripts/hooks/install.sh` installs the pinned commit_gate revision in `.tools/commit_gate` and both Git hooks.
  The pre-commit hook scans staged content; commit-msg enforces note-review trailers before the regression test gate.
  `scripts/quality/check_all.sh` also scans the full working tree. Python 3.11 or newer is required.
- Comments follow commit_gate defaults: recognized tool directives or a single-line `Edge case:` /
  `Workaround: <issue URL>` note, at most 100 characters after the prefix, three notes per file and two net new
  notes per commit. No TODO/FIXME, prose or private documentation comments. Retained changed-file notes need
  `Notes-reviewed: path:line` trailers after checking why each retained note is still necessary; the `trailers` command lists requirements.
- The instruction-file gate is enabled. `.agents` and `.claude` contain externally maintained skill packages and
  are excluded from source scanning; application, test, script and website sources remain in scope. No policy
  limit is relaxed. The optional independent-review and universal mirror-test gates are not enabled; Dictum's
  existing regression-test gate and review skill remain in place.
- Longer implementation constraints and script usage notes live in
  [implementation-constraints.md](implementation-constraints.md).
- `scripts/quality/check_log_privacy.py` rejects `dlog` interpolations whose names suggest
  dictated content; reduce them to `.count` or a flag rather than renaming around the check.
- Periphery's known false positives are in `.periphery.baseline.json`; check each new finding
  before regenerating it with `--write-baseline`.
- Duplicate detection is manual: `.tools/lizard/bin/lizard -l swift -Eduplicate .`.
