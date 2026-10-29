---
name: dictum-review
description: Review pending Dictum changes before committing. Runs a correctness review of the diff and audits it against Dictum's own rules in AGENTS.md and docs/ (privacy of dictated text in logs, event-tap fast path, .strings encoding and key parity, comment policy, Observation injection, project.yml vs xcodeproj, dependency pins). Use before committing, when the user asks to review Dictum changes, or when the user runs /dictum-review.
---

# dictum-review

Agent-neutral; follow it with whatever tools you have. This workflow reviews and reports. It
never commits, pushes or rewrites history.

An argument, if given, is the review effort (`low|medium|high`); default `high`.

## Step 1: Read the rules

Read `AGENTS.md` and every doc it links that matches the changed areas.

## Step 2: Scope

```sh
git status --porcelain
git diff HEAD --stat
git diff HEAD
```

Untracked files are part of the change. Note which areas are touched: Swift sources by module,
`Resources/*.strings`, `project.yml`, `.github/workflows/`, `scripts/`, `docs/`.

## Step 3: Gates

Run `spells check` (or `scripts/quality/check_all.sh`). Every failure is a finding; quote the
tool output.

## Step 4: Correctness review

Review the diff for real bugs: wrong state transitions in `DictationPipeline`, cancellation not
reaching the work (`isAborted`), actor reentrancy in `TranscriptionEngine`/`LLMProcessor`, main
actor violations, leaks of observers, monitors or timers, behavior changes in refactors. If the
host provides a code-review skill, use it at the given effort.

## Step 5: Dictum rule audit

Check each item that applies to the touched files. Report a finding with file and line.

| Rule | How to check |
| --- | --- |
| No dictated text, context or LLM output in logs | Every new or changed `dlog(` interpolates only counts, flags, ids, durations |
| Event tap stays fast | Nothing in `GlobalHotkeyMonitor.handleEvent` and its callees does I/O, logging per event, locks held long, or synchronous waits |
| `.strings` encoding and parity | Files still UTF-16 LE with BOM; new keys in both tables; `check_strings.py` passes |
| New `@Observable` store used by views | Injected with `.environment(...)` in `MenuBarController.setupPopover` |
| New root-level Swift file | Listed in `project.yml` `sources`; `Dictum.xcodeproj` regenerated, not hand-edited |
| Dependency bump | Matches the pin comments in `project.yml`; Sparkle bump also updates `release.yml` version and SHA |
| Comments | Only `// Edge case:` (≤ 4 lines), `TODO:`/`FIXME:`, directives; edge-case notes still true for the code beside them |
| Naming | New types, functions and properties say what they do without a comment |
| Docs | A change to behavior described in `docs/` updates that doc in the same change |
| Tests | No new test target added without the owner's consent |

## Step 6: Report

Group findings as **Blocking** (bugs, rule violations, gate failures) and **Suggestions**. For
each: file:line, what is wrong, the concrete fix. End with whether the change is ready to commit
and which `dictum-qa` sections to run for it.
