---
name: release
description: Automate release preparation for Dictum. Determines version bump, updates project.yml/CHANGELOG.md, commits, tags, and pushes. Use when the user wants to publish a new release.
---

You are preparing a new release for **Dictum**, a native macOS menu bar app for voice dictation. The user may optionally provide a version number or bump keyword.

## Step 1: Parse User Input

Extract from `$ARGUMENTS`:
- **Explicit version** (e.g., `1.1.0`, `2.0.0`) — use this exact version
- **Bump keyword** (`major`, `minor`, or `patch`) — apply this bump to the current version
- **Empty** — auto-determine the bump type from commit analysis

## Step 2: Pre-flight Checks

Run these checks before doing anything else. If any fail, **abort immediately** with a clear error message.

1. **Clean working tree**: Run `git status --porcelain`. If there is any output, abort — tell the user to commit or stash their changes first.
2. **On main branch**: Run `git branch --show-current`. If the result is not `main`, abort — tell the user to switch to `main`.
3. **In sync with remote**: Run `git fetch origin main` then compare `git rev-parse HEAD` with `git rev-parse origin/main`. If they differ, abort — tell the user to pull or push first.

## Step 3: Quality Gates

Build the project to ensure it compiles. If it fails, **abort** and ask the user to fix the issues first.

```bash
xcodegen generate && xcodebuild -project Dictum.xcodeproj -scheme Dictum -configuration Release CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" 2>&1 | tail -5
```

## Step 4: Analyze Commits & Determine Version

1. Get the latest git tag: `git describe --tags --abbrev=0` (if no tags exist, treat all commits as new)
2. Get current version from `project.yml` (the `MARKETING_VERSION` field)
3. List all commits since the latest tag: `git log <latest_tag>..HEAD --oneline`
4. Parse each commit using Conventional Commits format (`type(scope): description`):
   - Extract the **type** (e.g., `feat`, `fix`, `refactor`)
   - Extract the **scope** if present
   - Extract the **description**
   - Check for breaking changes: `BREAKING CHANGE:` in body/footer or `!` after type (e.g., `feat!:`)

5. **Determine version bump** (unless user provided explicit version or keyword):
   - Any breaking change → **MAJOR** bump
   - Any `feat` commit → **MINOR** bump
   - Only `fix`, `refactor`, `style`, `perf`, `docs` → **PATCH** bump
   - No user-facing commits (only `chore`, `test`, `ci`, `build`) → Use `AskUserQuestion` to ask whether to proceed with a PATCH release or abort

6. If user provided a bump keyword (`major`/`minor`/`patch`), apply it to the current version.
7. If user provided an explicit version, validate it is higher than the current version.

## Step 5: Generate CHANGELOG Entry

Map commits to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) categories:

| Commit type          | CHANGELOG category | Include? |
|----------------------|--------------------|----------|
| `feat`               | **Added**          | Yes      |
| `fix`                | **Fixed**          | Yes      |
| `refactor`           | **Changed**        | Yes      |
| `style`              | **Changed**        | Yes      |
| `perf`               | **Changed**        | Yes      |
| `chore`              | —                  | Skip     |
| `test`               | —                  | Skip     |
| `ci`                 | —                  | Skip     |
| `build`              | —                  | Skip     |
| `docs`               | —                  | Skip     |
| `chore(release)`     | —                  | Skip     |

Rules:
- **Only include categories that have actual entries.** Do NOT add empty categories.
- Write **human-friendly descriptions**, not raw commit messages.
- Group related commits when appropriate.

Format:
```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added

- Feature description

### Fixed

- Fix description
```

## Step 6: Review & Confirm

Present a summary to the user before making any file changes:

```
Release Summary
───────────────
Current version: A.B.C
New version:     X.Y.Z (BUMP_TYPE bump)

Commits since last release: N total (M user-facing, K skipped)

CHANGELOG preview:
──────────────────
## [X.Y.Z] - YYYY-MM-DD

### Added
- ...

### Fixed
- ...
```

Use `AskUserQuestion` to confirm: "Does this release summary look correct? Should I proceed with updating files?"

Allow the user to request edits to the CHANGELOG content before proceeding.

## Step 7: Update Files

1. **`project.yml`**: Update the `MARKETING_VERSION` field to the new version.

2. **`CHANGELOG.md`**: Insert the new version section directly after the `## [Unreleased]` heading. Move any entries from `[Unreleased]` into the new version section. Add a new empty `## [Unreleased]` at the top. Update the comparison links at the bottom of the file.

## Step 8: Commit & Tag

1. Stage changes: `git add project.yml CHANGELOG.md`
2. Create commit:
   ```
   git commit -m "chore(release): bump version to X.Y.Z"
   ```
3. Create annotated tag:
   ```
   git tag -a vX.Y.Z -m "Release version X.Y.Z"
   ```

## Step 9: Push to Repository

**IMPORTANT**: Pushing the tag will trigger the GitHub Actions `release.yml` workflow, which builds the app and creates a GitHub Release with `Dictum.zip`.

Use `AskUserQuestion` to confirm: "Ready to push? This will trigger the GitHub Actions build and create a GitHub Release with Dictum.app."

If confirmed:
```
git push origin main --follow-tags
```

After pushing, inform the user:
- The `release.yml` workflow has been triggered
- It will: build the Release .app, zip it, and create a GitHub Release with the changelog
- They can monitor progress at the repository's Actions tab

If something goes wrong after push, provide rollback instructions:
```bash
# Delete remote tag
git push origin :refs/tags/vX.Y.Z
# Delete local tag
git tag -d vX.Y.Z
# Revert the release commit
git revert HEAD
git push origin main
```
