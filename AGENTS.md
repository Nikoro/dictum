# AGENTS.md

## Rules

- After every code change run `spells run` and `spells test`, then verify it with the `dictum-qa`
  skill.
- Every bug fix is red, green, refactor: first a test in `DictumTests/` that reproduces the bug and
  fails, then the fix. The `commit-msg` hook blocks a `fix:` commit without one — details in
  [docs/quality-gates.md](docs/quality-gates.md).
- English everywhere except the Polish values in `Resources/*.xcstrings`.
- `dlog` must never log dictated text, context or LLM output.

## Read before working on

| Area | Doc |
| --- | --- |
| Pipeline, views, event tap | [docs/architecture.md](docs/architecture.md) |
| Building, toolchain | [docs/development.md](docs/development.md) |
| Lint, comments, dead code | [docs/quality-gates.md](docs/quality-gates.md) |
| User-facing strings | [docs/localization.md](docs/localization.md) |
