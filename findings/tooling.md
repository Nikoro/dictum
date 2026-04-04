# Tooling & CI

### [BUG] [CRITICAL] AppIcon silently dropped when PNGs have wrong pixel dimensions
**Area:** `Resources/Assets.xcassets/AppIcon.appiconset/`
**Tags:** `#gotcha` `#tooling`
**Verified:** 2026-03-28
**Trigger:** Built app shows generic macOS icon instead of custom purple mic icon.
**Root cause:** Every PNG in `AppIcon.appiconset` was exactly 2x its expected dimensions (e.g., `icon_16x16.png` was 32x32px, `icon_512x512@2x.png` was 2048x2048 instead of 1024x1024). `actool` classifies these as "Ambiguous Content" and **silently skips the entire AppIcon set** — no build error, no warning in default output, just a missing icon. The `Assets.car` compiles successfully but without any icon renditions. Only visible with `actool --warnings`.
**Fix applied:** Resized all PNGs to their correct dimensions using `sips`. Also added `CFBundleIconName: AppIcon` to `Info.plist` (was missing, required for asset catalog icon lookup).
**Note:** If generating icon sets from a single source image, verify each output file's pixel dimensions match the `size × scale` declared in `Contents.json` (e.g., `128x128` at `2x` = 256x256px actual).

### [GOTCHA] [CRITICAL] GitHub Actions macos-15 runner defaults to Xcode 16 — mlx-swift-lm fails to compile
**Area:** `.github/workflows/release.yml`
**Tags:** `#integration` `#tooling`
**Verified:** 2026-03-28
**Symptom:** Release workflow fails with `Jamba.swift:226: error: unexpected ',' separator` and warning `MACOSX_DEPLOYMENT_TARGET 26.0 not in supported range 10.13–15.0.99`.
**Root cause:** `macos-15` runner defaults to Xcode 16.4 (SDK macOS 15.0). `mlx-swift-lm` (currently pinned to 2.30.6) requires Swift features only available in Xcode 26+. Additionally, the project's macOS 26.0 deployment target is unsupported by Xcode 16.
**Workaround:** Use `macos-26` runner which defaults to Xcode 26.2. No `xcode-select` needed. Untested alternative: `macos-15` may have Xcode 26.x at `/Applications/Xcode_26.x.app` — requires explicit `xcode-select`.

### [GOTCHA] [GOTCHA] Claude Code Write tool double-escapes backslashes in .strings files
**Area:** `Resources/pl.lproj/Localizable.strings`
**Tags:** `#gotcha` `#tooling`
**Verified:** 2026-03-26
**Symptom:** Polish characters (ę, ł, ś, ć, etc.) display as literal `\U0119` text instead of rendered Unicode.
**Root cause:** The Write tool escapes backslashes, turning `\U0119` (Apple .strings Unicode escape) into `\\U0119` (literal text). The .strings parser sees a literal backslash, not a Unicode escape.
**Workaround:** Write .strings files via `python3 -c` with real UTF-8 characters, bypassing the Write tool's escaping. Example:
```
python3 -c "
with open('Resources/pl.lproj/Localizable.strings', 'w') as f:
    f.write('\"key\" = \"warto\u015b\u0107\";\n')
"
```
