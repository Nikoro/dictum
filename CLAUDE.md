# CLAUDE.md

## Co to jest

Dictum — natywna macOS menu bar app (Swift/SwiftUI) do dyktowania tekstu po polsku. Pipeline: mikrofon → WhisperKit STT → LLM cleanup (MLX Swift) → auto-paste. 100% on-device.

## Build

- **Wymaga Xcode 16+** — MLX Swift kompiluje Metal shaders, `swift build` nie działa
- Projekt generowany przez XcodeGen: `xcodegen generate` → `open Dictum.xcodeproj`
- Plik konfiguracyjny: `project.yml`
- Non-sandboxed app (globalny hotkey + Accessibility API)
- Deployment target: macOS 26.0, Apple Silicon only
- Code signing: Manual, `CODE_SIGN_IDENTITY: "Dictum Development"`, pusty `DEVELOPMENT_TEAM` — wymaga lokalnej konfiguracji

## Dependencies (SPM via XcodeGen)

- `WhisperKit` — `branch: main` (floating pin, API niestabilne <1.0)
- `mlx-swift-lm` 2.29.3 (exact pin, produkty: `MLXLLM`, `MLXLMCommon`; `mlx-swift` jest zależnością tranzytywną)

## Architektura

### Warstwy

- **DictumApp.swift** — `@main`, `NSApplicationDelegateAdaptor(AppDelegate.self)` → `AppDelegate` → `MenuBarManager`
- **DictationPipeline.swift** — singleton orkiestrator, łączy wszystkie warstwy, obsługuje hotkey callbacks; definiuje `dlog()` → `/tmp/dictum.log`
- **Audio/** — `AudioRecorder` — AVAudioEngine, PCM Float32 16kHz mono, konwersja formatu jeśli hardware ≠ 16kHz
- **Transcription/** — `TranscriptionEngine` (actor), `WhisperModelManager` — lazy load modeli
- **TextProcessing/** — `LLMProcessor` (actor) — MLX Swift, `ChatSession` API; automatycznie stripuje Qwen3 `<think>...</think>` bloki
- **ModelBrowser/** — `ModelBrowser` (HuggingFace API, debounce 300ms), `DownloadedModelsManager` (skan `~/Library/Caches/models/mlx-community/`)
- **FloatingIndicator/** — `FloatingIndicatorManager` — NSPanel floating pill przy kursorze tekstu (AX API), pokazuje stan nagrywania + audio level; fallback na pozycję myszy gdy AX niedostępne
- **MenuBar/** — `MenuBarManager` (NSStatusItem + NSPopover), `PopoverView` (pełny UI + onboarding `SetupView`), `MenuBarIcon` (NSImage factory per AppState — template icon + custom recording icon)
- **HotkeyAndPaste/** — `GlobalHotkeyManager` (CGEvent tap, dwa tryby: modifier-only i key+modifier), `PasteManager` (NSPasteboard + CGEvent Cmd+V, save/restore clipboard)
- **Settings/** — `AppSettings` singleton (`@AppStorage` + `@Published` state), `PermissionsManager` singleton (AX + Microphone polling), `AppState` enum

### Kluczowe wzorce

- `TranscriptionEngine` i `LLMProcessor` to **Swift actors** (thread safety)
- Modele ładowane **lazy** — przy pierwszym nagraniu, nie przy starcie app
- `AppSettings.shared` — singleton z `@AppStorage` + `@Published` state
- `DictationPipeline.shared` — singleton orkiestrator
- CGEvent tap wymaga Accessibility permission — `AXIsProcessTrusted()` (system prompt via `AXIsProcessTrustedWithOptions`, ale auto-grant niemożliwy)
- Popover UI zbudowany z sekcji: Header, Prompt, RecordingSettings, STTModel, LLMModel, DownloadedModels, Footer
- **Onboarding**: `SetupView` gate — `isSetupComplete = allGranted && downloadedModelIds.contains(sttModelId)`. 3 kroki: permissions → STT download → opcjonalny LLM download
- **Hotkey**: domyślnie Right ⌘ (keyCode 54) w trybie modifier-only; alternatywnie key+modifier combo

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
- Stany ikony menu bar: idle (template mic.fill), recording (custom icon z czerwoną kropką REC), reszta stanów używa template icon (brak osobnych kolorów dla transcribing/processingLLM/done)

## Debugging

- `dlog()` → `tail -f /tmp/dictum.log` — wszystkie logi pipeline (40+ callsites)

## Persistence (AppStorage keys)

| Key | Type | Default | Owner |
|---|---|---|---|
| `llmPrompt` | String | Polish cleanup prompt | `AppSettings` |
| `sttModelId` | String | `openai_whisper-large-v3_turbo` | `AppSettings` |
| `llmModelId` | String | `mlx-community/Qwen3.5-4B-4bit` | `AppSettings` |
| `recordingMode` | String | `hold` | `AppSettings` |
| `llmCleanupEnabled` | Bool | `false` | `AppSettings` |
| `hotkeyKeyCode` | Int | `54` (Right ⌘) | `AppSettings` |
| `hotkeyModifiers` | Int | `0` | `AppSettings` |
| `hotkeyIsModifierOnly` | Bool | `true` | `AppSettings` |
| `whisperDownloadedModelIds` | [String] | `[]` | `WhisperModelManager` |

## Testy

Brak testow — manual QA only. Nie dodawaj XCTest bez pytania.

## Znane ograniczenia

- WhisperKit API niestabilne (<1.0) — branch: main, może się zepsuć między clone'ami
- MLX Swift wymaga xcodebuild (Metal shaders)
- Accessibility permission — system prompt via `AXIsProcessTrustedWithOptions`, ale auto-grant niemożliwy; user potwierdza ręcznie
- Pierwsze uruchomienie modelu WhisperKit: CoreML kompilacja na ANE, 30-60s
- RAM: WhisperKit ~3GB + LLM ~2.5GB = ~5.5GB unified memory
- Whisper language hardcoded na `"pl"` (Polish) w `TranscriptionEngine` — brak UI do zmiany
- FloatingIndicator fallback na pozycję myszy gdy app nie eksponuje AX text role (Electron, terminale)

## Findings

See [FINDINGS.md](FINDINGS.md) for crucial discoveries and "aha moments" captured during development sessions. Review before making changes to unfamiliar areas.
