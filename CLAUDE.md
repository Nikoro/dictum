# CLAUDE.md

## Co to jest

Dictum — natywna macOS menu bar app (Swift/SwiftUI) do dyktowania tekstu po polsku. Pipeline: mikrofon → WhisperKit STT → LLM cleanup (MLX Swift) → auto-paste. 100% on-device.

## Build

- **Wymaga Xcode 16+** — MLX Swift kompiluje Metal shaders, `swift build` nie działa
- Projekt generowany przez XcodeGen: `xcodegen generate` → `open Dictum.xcodeproj`
- Plik konfiguracyjny: `project.yml`
- Non-sandboxed app (globalny hotkey + Accessibility API)
- Deployment target: macOS 14.0+, Apple Silicon only

## Dependencies (SPM via XcodeGen)

- `WhisperKit` 0.9.4 (exact pin — API niestabilne, zmienia się między wersjami)
- `mlx-swift` 0.21.0+
- `mlx-swift-lm` 0.2.0+ (produkty: `MLXLLM`, `MLXLMCommon`)

## Architektura

### Warstwy

- **DictumApp.swift** — `@main`, `NSApplicationDelegateAdaptor` → `MenuBarManager`
- **DictationPipeline.swift** — singleton orkiestrator, łączy wszystkie warstwy, obsługuje hotkey callbacks
- **Audio/** — `AudioRecorder` — AVAudioEngine, PCM Float32 16kHz mono, konwersja formatu jeśli hardware ≠ 16kHz
- **Transcription/** — `TranscriptionEngine` (actor), `WhisperModelManager` — lazy load modeli
- **TextProcessing/** — `LLMProcessor` (actor) — MLX Swift, chat messages format
- **ModelBrowser/** — `ModelBrowser` (HuggingFace API, debounce 300ms), `DownloadedModelsManager` (skan `~/.cache/huggingface/hub/`)
- **MenuBar/** — `MenuBarManager` (NSStatusItem + NSPopover), `PopoverView` (pełny UI)
- **HotkeyAndPaste/** — `GlobalHotkeyManager` (CGEvent tap), `PasteManager` (NSPasteboard + CGEvent Cmd+V)
- **Settings/** — `AppSettings` singleton, `@AppStorage`, `AppState` enum

### Kluczowe wzorce

- `TranscriptionEngine` i `LLMProcessor` to **Swift actors** (thread safety)
- Modele ładowane **lazy** — przy pierwszym nagraniu, nie przy starcie app
- `AppSettings.shared` — singleton z `@AppStorage` + `@Published` state
- `DictationPipeline.shared` — singleton orkiestrator
- CGEvent tap wymaga Accessibility permission — `AXIsProcessTrusted()`
- Popover UI zbudowany z sekcji: Header, Prompt, RecordingSettings, STTModel, LLMModel, DownloadedModels, Footer

### Flow danych

```
Hotkey (GlobalHotkeyManager) → DictationPipeline
  → AudioRecorder.startRecording()
  → AudioRecorder.stopRecording() → [Float]
  → TranscriptionEngine.transcribe() → String (surowy)
  → LLMProcessor.cleanText() → String (czysty)  [opcjonalnie]
  → PasteManager.pasteText() → Cmd+V
```

## Konwencje

- Język UI: polski
- Kod/komentarze: angielski (nazwy typów/funkcji), polski w stringach UI
- Brak historii transkrypcji — app nie przechowuje danych użytkownika
- `LSUIElement = true` — app nie pojawia się w Dock
- Stany ikony menu bar: idle (szary), recording (czerwony pulsujący), transcribing (żółty), processingLLM (pomarańczowy), done (zielony flash 1s), error (czerwony stały)

## Znane ograniczenia

- WhisperKit API niestabilne (<1.0) — pinuj exact version
- MLX Swift wymaga xcodebuild (Metal shaders)
- Accessibility permission nie da się poprosić programowo — user dodaje ręcznie
- Pierwsze uruchomienie modelu WhisperKit: CoreML kompilacja na ANE, 30-60s
- RAM: WhisperKit ~3GB + LLM ~2.5GB = ~5.5GB unified memory
