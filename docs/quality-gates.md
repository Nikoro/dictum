# Quality gates

- Never bypass the pre-commit or commit-msg hook with `--no-verify`.
- A `fix:` commit that stages app Swift code must also stage a test in the mirror location
  (`Transcription/Foo.swift` → `DictumTests/Transcription/FooTests.swift`, extend it if it exists),
  and the suite must pass (`scripts/quality/check_regression_test.sh`). The test must fail before
  the fix; one that passes either way does not count. A layout-only fix gets `refactor:` instead of
  an invented test.
- Tests use Swift Testing and run hosted in the app; `DictumApp` skips its startup under XCTest.
  Logic that touches the file system takes its directories as parameters so tests use temp folders.
- Comments only as `// Edge case:` notes (max 4 lines) for what the code cannot say, `// TODO:` /
  `// FIXME:`, or tool directives. Everything else becomes a better name or a smaller function.
- `scripts/quality/check_log_privacy.py` rejects `dlog` interpolations whose names suggest
  dictated content; reduce them to `.count` or a flag rather than renaming around the check.
- Periphery's known false positives are in `.periphery.baseline.json`; check each new finding
  before regenerating it with `--write-baseline`.
- Duplicate detection is manual: `.tools/lizard/bin/lizard -l swift -Eduplicate .`.
