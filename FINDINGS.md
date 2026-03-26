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

## Paste & Hotkey

### [BUG] [GOTCHA] CGEvent paste requires `.cgAnnotatedSessionEventTap`
**Area:** `HotkeyAndPaste/PasteManager.swift`
**Tags:** `#gotcha` `#integration`
**Verified:** 2026-03-26
**Trigger:** Transcription completes, clipboard is set, Cmd+V is simulated, but nothing pastes into the target app.
**Root cause:** Events posted to `.cghidEventTap` weren't reaching the frontmost app reliably. The app's own CGEvent tap for hotkey detection may also interfere.
**Fix applied:** Changed all 4 CGEvent posts (Cmd↓, V↓, V↑, Cmd↑) to use `.cgAnnotatedSessionEventTap`. Also increased pre-paste delay to 0.15s and clipboard restore delay to 0.5s.

## Tooling

### [GOTCHA] [GOTCHA] Claude Code Write tool double-escapes backslashes in .strings files
**Area:** `Resources/pl.lproj/Localizable.strings`
**Tags:** `#gotcha` `#tooling`
**Verified:** 2026-03-26
**Symptom:** Polish characters (ę, ł, ś, ć, etc.) display as literal `\U0119` text instead of rendered Unicode.
**Root cause:** The Write tool escapes backslashes, turning `\U0119` (Apple .strings Unicode escape) into `\\U0119` (literal text). The .strings parser sees a literal backslash, not a Unicode escape.
**Workaround:** Write .strings files via `python3 -c` with real UTF-8 characters (e.g., `\u0119` in Python source → raw ę bytes in file), bypassing the Write tool's escaping.
