# Dictum

> *Dictum* (łac.) — "powiedziane", "wypowiedziane słowo"

Natywna macOS menu bar app do dyktowania tekstu. Zamienia mowę (polski) na tekst i automatycznie wkleja go w aktywne okno. Wszystko 100% on-device, zero chmury.

**Pipeline:** mikrofon → WhisperKit (CoreML, Neural Engine) → surowy tekst → lokalny LLM (MLX Swift) → czysty tekst → auto-paste

## Wymagania

| | Minimum |
|---|---|
| macOS | 14.0+ (Sonoma) |
| Chip | Apple Silicon (M1+) |
| RAM | 16 GB (32 GB rekomendowane) |
| Dysk | ~5 GB na modele |
| Xcode | 16.0+ |

## Stack

- **STT:** [WhisperKit](https://github.com/argmaxinc/WhisperKit) — large-v3-turbo, CoreML na Neural Engine
- **LLM:** [MLX Swift](https://github.com/ml-explore/mlx-swift) + [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm) — Qwen3 4B 4-bit (domyślnie)
- **Audio:** AVAudioEngine — PCM Float32, 16kHz mono
- **Auto-paste:** CGEvent Cmd+V przez Accessibility API

## Build

```bash
# Wymagany XcodeGen
brew install xcodegen

# Generuj projekt Xcode
xcodegen generate

# Otwórz w Xcode i zbuduj (Cmd+R)
open Dictum.xcodeproj
```

> **Uwaga:** Projekt wymaga budowania przez Xcode (`xcodebuild`), nie `swift build` — MLX Swift kompiluje Metal shaders.

## Uprawnienia

Po pierwszym uruchomieniu:

1. **Mikrofon** — system zapyta automatycznie
2. **Accessibility** — ręcznie: System Settings → Privacy & Security → Accessibility → dodaj Dictum

## Użycie

1. Kliknij ikonę mikrofonu w menu bar — otwiera popover z ustawieniami
2. Naciśnij hotkey (domyślnie `⌥ Space`) — rozpoczyna nagrywanie
3. Mów po polsku
4. Puść klawisz (hold mode) lub naciśnij ponownie (toggle mode)
5. Tekst zostanie automatycznie wklejony w aktywne okno

### Stany ikony

| Kolor | Stan |
|-------|------|
| Szary | Gotowy |
| Czerwony (pulsujący) | Nagrywanie |
| Żółty | Transkrypcja |
| Pomarańczowy | Przetwarzanie LLM |
| Zielony (flash 1s) | Gotowe |

## Architektura

```
├── DictumApp.swift              # @main, App lifecycle
├── DictationPipeline.swift      # Orkiestrator: hotkey → record → STT → LLM → paste
├── Audio/
│   └── AudioRecorder.swift      # AVAudioEngine, PCM 16kHz mono
├── Transcription/
│   ├── TranscriptionEngine.swift    # WhisperKit actor
│   └── WhisperModelManager.swift    # Lista modeli Whisper, download, switch
├── TextProcessing/
│   └── LLMProcessor.swift      # MLX Swift LLM actor
├── ModelBrowser/
│   ├── ModelBrowser.swift       # HuggingFace API search (debounced)
│   └── DownloadedModelsManager.swift  # Skan cache, usuwanie modeli
├── MenuBar/
│   ├── MenuBarManager.swift     # NSStatusItem + NSPopover
│   └── PopoverView.swift        # Pełny UI popovera
├── HotkeyAndPaste/
│   ├── GlobalHotkeyManager.swift    # CGEvent tap, hold/toggle
│   └── PasteManager.swift      # NSPasteboard + CGEvent Cmd+V
├── Settings/
│   └── AppSettings.swift        # @AppStorage, stany app
└── Resources/
    ├── Info.plist
    └── Dictum.entitlements
```

## Konfiguracja modeli

### STT (Whisper)
Wbudowana lista modeli WhisperKit — wybierz w popoverze. Modele pobierają się automatycznie przy pierwszym wyborze.

### LLM
Wyszukiwarka HuggingFace z live search — filtruje `mlx-community`, sortuje po popularności. Kliknięcie pobiera i aktywuje model. Można wyłączyć LLM cleanup togglem.

## Licencja

Projekt prywatny.
