# Findings

Crucial discoveries and "aha moments" captured during development sessions.

## Transcription & Audio

### [GOTCHA] [CRITICAL] WhisperKit model download state not persisted on disk
**Area:** `Transcription/WhisperModelManager.swift`
**Tags:** `#gotcha` `#integration`
**Verified:** 2026-03-26
**Symptom:** After every app rebuild, setup screen asks to download the STT model again even though it was already downloaded.
**Root cause:** WhisperKit doesn't store models in a scannable disk location. The original `scanDownloaded()` checked HuggingFace cache dirs (`~/Library/Caches/huggingface/`, `~/.cache/huggingface/`) but found nothing — WhisperKit manages its own cache internally.
**Workaround:** Persist downloaded model IDs in `UserDefaults` (`whisperDownloadedModelIds` key) after successful `loadModel()`. Don't rely on filesystem scanning.
**Note:** This applies only to STT (WhisperKit) models. LLM models (MLX) *are* disk-scanned via `DownloadedModelsManager` at `~/Library/Caches/models/mlx-community/`.

### [GOTCHA] [CRITICAL] Whisper hallucinates on short audio when model loads lazily
**Area:** `DictationPipeline.swift`
**Tags:** `#gotcha` `#architecture`
**Verified:** 2026-03-26
**Symptom:** User says "raz dwa trzy" but Whisper transcribes "Dziękuję." every time.
**Root cause:** STT model loaded lazily after `stopRecording()`. Loading takes ~5s, during which no audio is captured. Result: only ~2.5s of audio (40960 samples at 16kHz), often too short/quiet for Whisper, triggering hallucination of common Polish phrases.
**Workaround:** Preload STT model at app startup (`preloadSTTModel()` in `DictationPipeline.init`) so it's ready before first recording.

## UI & Rendering

### [GOTCHA] [GOTCHA] `.background(.ultraThinMaterial)` kills `.glassEffect()` rendering
**Area:** `FloatingIndicator/FloatingIndicatorManager.swift`
**Tags:** `#gotcha` `#integration`
**Verified:** 2026-03-26
**Symptom:** Floating pill renders with flat black background instead of liquid glass effect.
**Root cause:** `.background(.ultraThinMaterial, in: Capsule())` applied before `.glassEffect(.regular, in: .capsule)` overrides the glass rendering. The material fills the shape opaquely.
**Workaround:** Remove `.background(.ultraThinMaterial)` entirely. Use `.glassEffect()` alone — it provides its own translucency.

### [GOTCHA] [NOTE] TimelineView reconstructs child views — onAppear fires repeatedly
**Area:** `FloatingIndicator/FloatingIndicatorManager.swift`
**Tags:** `#gotcha` `#architecture`
**Verified:** 2026-03-26
**Symptom:** Dot animation timer multiplied — "Transkrybuję" showed 4-6 dots instead of max 3.
**Root cause:** Views inside `TimelineView(.animation)` get reconstructed every frame (~60Hz). Each reconstruction can trigger `.onAppear`, creating duplicate `Timer.scheduledTimer` instances.
**Workaround:** Guard timer creation with `guard dotTimer == nil`, store timer in `@State`, and clean up on `.onDisappear`.

### [GOTCHA] [NOTE] @Published changes don't propagate across NSPanel window boundary
**Area:** `FloatingIndicator/FloatingIndicatorManager.swift`
**Tags:** `#gotcha` `#architecture`
**Verified:** 2026-03-26
**Symptom:** Audio level bars in floating pill don't move despite `audioLevel` being updated in `AudioRecorder`.
**Root cause:** `@Published` property changes from `ObservableObject` in the main app don't reliably trigger `@ObservedObject` updates in a SwiftUI view hosted in a separate `NSPanel` window.
**Workaround:** Use `TimelineView(.animation(minimumInterval: 0.016))` to poll `audioRecorder.audioLevel` directly at 60Hz instead of relying on Combine observation.

## LLM Processing

### [GOTCHA] [NOTE] Qwen3 emits `<think>...</think>` blocks that must be stripped
**Area:** `TextProcessing/LLMProcessor.swift`
**Tags:** `#gotcha` `#integration`
**Verified:** 2026-03-27
**Symptom:** LLM output contains chain-of-thought reasoning text before the actual cleaned transcription.
**Root cause:** Qwen3 models (including Qwen3.5-4B-4bit) emit `<think>...</think>` blocks as part of their generation. `LLMProcessor.cleanText()` strips everything up to and including `</think>`.
**Scope:** Model-specific — if switching to a non-Qwen model that doesn't emit `<think>`, the strip is a safe no-op. If switching to a model that uses different delimiters, output will be corrupted.

## Settings & Persistence

### [NOTE] [NOTE] llmDownloadedModelId is a one-way write — never cleared on model deletion
**Area:** `MenuBar/PopoverView.swift`, `Settings/AppSettings.swift`
**Tags:** `#architecture` `#gotcha`
**Verified:** 2026-03-28
**Symptom:** After deleting an LLM model, onboarding does not re-trigger.
**Root cause:** `llmDownloadedModelId` is set during onboarding when the user downloads an LLM model, but is never cleared when the model is deleted via `DownloadedModelsManager`. This is intentional — only the STT model gate (`whisperDownloadedModelIds`) is authoritative for `isSetupComplete`. The LLM download step in onboarding is optional.
**Note:** If debugging "why doesn't setup re-show after LLM model deletion" — this is by design.

## Paste & Hotkey

### [BUG] [GOTCHA] CGEvent paste requires `.cgAnnotatedSessionEventTap`
**Area:** `HotkeyAndPaste/PasteManager.swift`
**Tags:** `#gotcha` `#integration`
**Verified:** 2026-03-26
**Trigger:** Transcription completes, clipboard is set, Cmd+V is simulated, but nothing pastes into the target app.
**Root cause:** Events posted to `.cghidEventTap` weren't reaching the frontmost app reliably. The app's own CGEvent tap for hotkey detection may also interfere.
**Fix applied:** Changed all 4 CGEvent posts (Cmd↓, V↓, V↑, Cmd↑) to use `.cgAnnotatedSessionEventTap`. Also increased pre-paste delay to 0.15s and clipboard restore delay to 0.5s.

### [GOTCHA] [NOTE] SelectedTextReader.readSelectedText() must never run on event tap's run loop thread
**Area:** `HotkeyAndPaste/SelectedTextReader.swift`, `HotkeyAndPaste/GlobalHotkeyManager.swift`
**Tags:** `#gotcha` `#architecture`
**Verified:** 2026-03-28
**Symptom:** `readSelectedText()` returns `nil` (clipboard unchanged) even when text is selected.
**Root cause:** The method sends Cmd+C via `.cghidEventTap` then `Thread.sleep(0.05)` to wait for clipboard. If called on the same run loop thread that processes CGEvents, the sleep blocks delivery of the very event it just posted → deadlock (clipboard never updates).
**Workaround:** `GlobalHotkeyManager` correctly dispatches to `DispatchQueue.global` before calling. If the call site ever moves, the bug is silent (no crash, just `nil` return).

## App Icon & Asset Catalog

### [BUG] [CRITICAL] AppIcon silently dropped when PNGs have wrong pixel dimensions
**Area:** `Resources/Assets.xcassets/AppIcon.appiconset/`
**Tags:** `#gotcha` `#tooling`
**Verified:** 2026-03-28
**Trigger:** Built app shows generic macOS icon instead of custom purple mic icon.
**Root cause:** Every PNG in `AppIcon.appiconset` was exactly 2x its expected dimensions (e.g., `icon_16x16.png` was 32x32px, `icon_512x512@2x.png` was 2048x2048 instead of 1024x1024). `actool` classifies these as "Ambiguous Content" and **silently skips the entire AppIcon set** — no build error, no warning in default output, just a missing icon. The `Assets.car` compiles successfully but without any icon renditions. Only visible with `actool --warnings`.
**Fix applied:** Resized all PNGs to their correct dimensions using `sips`. Also added `CFBundleIconName: AppIcon` to `Info.plist` (was missing, required for asset catalog icon lookup).
**Note:** If generating icon sets from a single source image, verify each output file's pixel dimensions match the `size × scale` declared in `Contents.json` (e.g., `128x128` at `2x` = 256x256px actual).

## CI & Build

### [GOTCHA] [CRITICAL] GitHub Actions macos-15 runner defaults to Xcode 16 — mlx-swift-lm fails to compile
**Area:** `.github/workflows/release.yml`
**Tags:** `#integration` `#tooling`
**Verified:** 2026-03-28
**Symptom:** Release workflow fails with `Jamba.swift:226: error: unexpected ',' separator` and warning `MACOSX_DEPLOYMENT_TARGET 26.0 not in supported range 10.13–15.0.99`.
**Root cause:** `macos-15` runner defaults to Xcode 16.4 (SDK macOS 15.0). `mlx-swift-lm` 2.29.3 requires Swift features only available in Xcode 26+. Additionally, the project's macOS 26.0 deployment target is unsupported by Xcode 16.
**Workaround:** Use `macos-26` runner which defaults to Xcode 26.2. No `xcode-select` needed. Untested alternative: `macos-15` may have Xcode 26.x at `/Applications/Xcode_26.x.app` — requires explicit `xcode-select`.

## Tooling

### [GOTCHA] [GOTCHA] Claude Code Write tool double-escapes backslashes in .strings files
**Area:** `Resources/pl.lproj/Localizable.strings`
**Tags:** `#gotcha` `#tooling`
**Verified:** 2026-03-26
**Symptom:** Polish characters (ę, ł, ś, ć, etc.) display as literal `\U0119` text instead of rendered Unicode.
**Root cause:** The Write tool escapes backslashes, turning `\U0119` (Apple .strings Unicode escape) into `\\U0119` (literal text). The .strings parser sees a literal backslash, not a Unicode escape.
**Workaround:** Write .strings files via `python3 -c` with real UTF-8 characters (e.g., `\u0119` in Python source → raw ę bytes in file), bypassing the Write tool's escaping.
