# AGENTS.md

## Rules

- After every code change run `spells run` and verify it with the `dictum-qa` skill. There are
  no automated tests; don't add a test target without asking.
- English everywhere except the Polish values in `Resources/*.xcstrings`.
- `dlog` must never log dictated text, context or LLM output.

## Read before working on

| Area | Doc |
| --- | --- |
| Pipeline, views, event tap | [docs/architecture.md](docs/architecture.md) |
| Building, toolchain | [docs/development.md](docs/development.md) |
| Lint, comments, dead code | [docs/quality-gates.md](docs/quality-gates.md) |
| User-facing strings | [docs/localization.md](docs/localization.md) |
