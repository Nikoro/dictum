# Quality gates

- Never bypass the pre-commit hook with `--no-verify`.
- Comments only as `// Edge case:` notes (max 4 lines) for what the code cannot say, `// TODO:` /
  `// FIXME:`, or tool directives. Everything else becomes a better name or a smaller function.
- `scripts/quality/check_log_privacy.py` rejects `dlog` interpolations whose names suggest
  dictated content; reduce them to `.count` or a flag rather than renaming around the check.
- Periphery's known false positives are in `.periphery.baseline.json`; check each new finding
  before regenerating it with `--write-baseline`.
- Duplicate detection is manual: `.tools/lizard/bin/lizard -l swift -Eduplicate .`.
