---
name: release
description: Automate release preparation for Dictum. Determines version bump, updates project.yml/CHANGELOG.md, commits, tags, and pushes. Use when the user wants to publish a new release.
---

You are preparing a new release of the **Dictum macOS app**, a menu bar app for voice dictation.
The user may optionally provide a version number or bump keyword.

Facts this skill relies on:

- Pushing a `v*` tag runs `.github/workflows/release.yml`. It builds the Release app with the
  Developer ID certificate (team `Y5T33B6749`), notarizes and staples it, and publishes `Dictum.zip`
  plus a Sparkle `appcast.xml` as a GitHub Release with the changelog section as notes. Nothing is
  signed or notarized locally.
- The signing identity must never change between releases: macOS ties Microphone and Accessibility
  grants to it and silently revokes them for every user.
- CI needs the `CERTIFICATE_P12`, `CERTIFICATE_PASSWORD`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`,
  `NOTARY_KEY_P8` and `SPARKLE_EDDSA_KEY` secrets; the `.p12` and `.p8` go in base64.
- `MARKETING_VERSION` in `project.yml` is shared with the iOS app. TestFlight builds may already use a
  version that was never tagged, and `CHANGELOG.md` may contain a dated section for it. The latest
  `v*` tag is the last public macOS release.
- CI overrides the macOS build number with a UTC timestamp for Sparkle ordering; the
  `CURRENT_PROJECT_VERSION` in `project.yml` is the iOS `YYMMDDNN` counter.

## Step 1: Parse User Input

Extract from `$ARGUMENTS`:
- **Explicit version** (e.g., `1.1.0`) — use this exact version
- **Bump keyword** (`major`, `minor`, or `patch`)
- **Empty** — auto-determine the bump from commit analysis

## Step 2: Pre-flight Checks

Abort with a clear message if any check fails:

1. **Clean working tree**: `git status --porcelain` prints nothing.
2. **On main**: `git branch --show-current` is `main`.
3. **In sync**: after `git fetch origin main`, `git rev-parse HEAD` equals `git rev-parse origin/main`.
   If local is only ahead, offer to push first.
4. **Secrets present**: `gh secret list` shows all six secrets listed above.

## Step 3: Quality Gates

All must pass; otherwise abort and report the failing output:

```bash
scripts/test.sh
scripts/quality/check_all.sh
xcodegen generate && xcodebuild -project Dictum.xcodeproj -scheme Dictum -configuration Release \
  CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" ARCHS=arm64 build 2>&1 | tail -3
```

The last command only proves the Release configuration compiles; never ship that ad-hoc build.

## Step 4: Analyze Commits & Determine Version

1. Latest public release: `git describe --tags --abbrev=0 --match 'v*'`.
2. Current `MARKETING_VERSION` from `project.yml`.
3. Commits since the tag: `git log <tag>..HEAD --format='%h %s%n%b'`.
4. Parse Conventional Commits; `!` after the type or `BREAKING CHANGE:` means breaking.
5. Bump, applied to the **higher** of the tag version and `MARKETING_VERSION`:
   - breaking → MAJOR; any `feat` → MINOR; only `fix`/`refactor`/`perf`/`style`/`docs` → PATCH
   - only `chore`/`test`/`ci`/`build` → ask whether to release a PATCH or abort
   - If `MARKETING_VERSION` is above the tag, has no tag and no dated CHANGELOG section, it was
     prepared but never released: release it as is unless commits demand more.
6. An explicit version must be higher than the latest tag and not lower than `MARKETING_VERSION`.

## Step 5: Generate CHANGELOG Entry

Turn `## [Unreleased]` plus the commits since the tag into a `## [X.Y.Z] - YYYY-MM-DD` section in
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format:

| Commit type | Category |
| --- | --- |
| `feat` | Added |
| `fix` | Fixed |
| `refactor`, `perf`, `style` | Changed |
| `chore`, `test`, `ci`, `build`, `docs`, `chore(release)` | skipped |

- Only categories with entries; human-friendly wording, related commits grouped.
- Drop internal bookkeeping from `[Unreleased]`: local or TestFlight build numbers, upload notes.
- Keep any dated but untagged section (an iOS TestFlight version) where it is.
- Links at the bottom: `[Unreleased]` compares `vX.Y.Z...HEAD`; `[X.Y.Z]` compares the previous tag
  with `vX.Y.Z`. An untagged version gets no link.

## Step 6: Review & Confirm

Show current tag, current `MARKETING_VERSION`, new version and bump type, commit counts, and the
CHANGELOG preview. Unless the user already asked to release without further confirmation, ask:
"Does this release summary look correct? Should I proceed?" and apply requested edits.

## Step 7: Update Files

1. `python3 scripts/version.py --version X.Y.Z` — sets `MARKETING_VERSION` and advances the shared
   build counter.
2. Write the CHANGELOG section and links from Step 5, leaving an empty `## [Unreleased]` on top.

## Step 8: Commit & Tag

```bash
xcodegen generate
git add project.yml CHANGELOG.md Dictum.xcodeproj
git commit -m "chore(release): bump version to X.Y.Z"
git tag -a vX.Y.Z -m "Release version X.Y.Z"
```

## Step 9: Push

Pushing the tag publishes the release to every user through Sparkle. Unless the user already asked
to push, confirm first: "Ready to push? This builds, notarizes and publishes Dictum X.Y.Z."

```bash
git push origin main --follow-tags
```

## Step 10: Verify the Published Release

1. Find the run: `gh run list --workflow release.yml --limit 1`. Tell the user it is running; check
   it again when they ask or when it should be done (about 15–25 minutes), and show the failing step
   log with `gh run view <id> --log-failed` if it failed.
2. When it succeeded:
   - `gh release view vX.Y.Z` lists `Dictum.zip` and `appcast.xml`.
   - Download and check notarization in a fresh temporary directory:
     ```bash
     dir=$(mktemp -d) && gh release download vX.Y.Z -p Dictum.zip -D "$dir" \
       && ditto -x -k "$dir/Dictum.zip" "$dir" \
       && spctl --assess --type execute --verbose "$dir/Dictum.app" \
       && xcrun stapler validate "$dir/Dictum.app"
     ```
   - The appcast `sparkle:shortVersionString` is `X.Y.Z`.

If something goes wrong after the push:

```bash
gh release delete vX.Y.Z --yes
git push origin :refs/tags/vX.Y.Z
git tag -d vX.Y.Z
git revert HEAD
git push origin main
```
