<p align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" alt="Dictum icon">
</p>

<h1 align="center">Dictum</h1>

<p align="center"><em>"something spoken", "a uttered word" — Latin</em></p>

<p align="center">
  <a href="https://github.com/Nikoro/dictum/releases/latest"><img src="https://img.shields.io/github/v/release/Nikoro/dictum?style=flat-square" alt="Release"></a>
  <a href="https://github.com/Nikoro/dictum"><img src="https://img.shields.io/badge/macOS-26.0+-black?style=flat-square&logo=apple" alt="macOS"></a>
  <!-- Keep Swift version in sync with SWIFT_VERSION in project.yml -->
  <a href="https://github.com/Nikoro/dictum"><img src="https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Nikoro/dictum?style=flat-square" alt="License"></a>
</p>

Native macOS menu bar app for voice dictation. Converts speech to text and auto-pastes it into the active window. Fully on-device — no cloud, no network.

**Pipeline:** microphone → WhisperKit (CoreML, Neural Engine) → raw text → local LLM (MLX Swift) → cleaned text → auto-paste

## Requirements

| | Minimum |
|---|---|
| macOS | 26.0 (Tahoe) |
| Chip | Apple Silicon (M1+) |
| RAM | 16 GB (32 GB recommended) |
| Disk | ~5 GB for models |
| Xcode | 26.0+ |

## Stack

- **STT:** [WhisperKit](https://github.com/argmaxinc/WhisperKit) — large-v3-turbo, CoreML on Neural Engine
- **LLM:** [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm) — Qwen3.5 4B 4-bit (default)
- **Audio:** AVAudioEngine — PCM Float32, 16kHz mono
- **Auto-paste:** CGEvent Cmd+V via Accessibility API

## Build

```bash
# Requires XcodeGen
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Open in Xcode and build (Cmd+R)
open Dictum.xcodeproj
```

> **Note:** Must be built with Xcode (`xcodebuild`), not `swift build` — MLX Swift compiles Metal shaders.

## Permissions

On first launch:

1. **Microphone** — system prompts automatically
2. **Accessibility** — manual: System Settings → Privacy & Security → Accessibility → add Dictum

## Usage

1. Click the microphone icon in the menu bar to open the settings popover
2. Press the hotkey (default: hold `Right ⌘`) to start recording
3. Speak (language: Polish by default)
4. Release the key (hold mode) or press again (toggle mode) — press `Escape` to cancel
5. Text is automatically pasted into the active window (or copied to clipboard in context mode)

### Menu bar icon states

| Icon | State |
|------|-------|
| Template mic.fill | Idle / Transcribing / Processing / Done |
| Custom (mic + red dot) | Recording |

## Features

- **On-device pipeline** — WhisperKit STT + MLX LLM, no network required
- **LLM text cleanup** — optional post-processing to fix punctuation, grammar, formatting
- **Context-aware dictation** — select text before dictating to use it as LLM context; result is copied to clipboard instead of auto-pasted
- **Per-app prompts** — custom LLM prompts per application (matched by bundle ID), with `{{text}}` placeholder
- **Model browser** — search and download models from HuggingFace (MLX community), manage downloaded models
- **Floating indicator** — translucent pill at the text cursor showing recording state and audio level
- **Configurable hotkey** — modifier-only (e.g. Right ⌘) or key+modifier combos
- **Hold / Toggle modes** — hold-to-record or press-to-start/press-to-stop
- **Onboarding** — guided setup: permissions → STT model download → optional LLM download

## Architecture

Hotkey → optional selected text capture → audio recording → WhisperKit STT → optional LLM cleanup → auto-paste (or clipboard in context mode). Settings and onboarding live in a menu bar popover, with a floating pill at the cursor during recording.

See [CLAUDE.md](CLAUDE.md) for the full layer-by-layer architecture reference.

## Download

Grab `Dictum.pkg` from the [latest release](https://github.com/Nikoro/dictum/releases/latest) and run the installer. It places Dictum in `/Applications` and removes the quarantine flag automatically.

Alternatively, download `Dictum.zip` and move the app manually.

## Known limitations

- WhisperKit API is unstable (pre-1.0) — pinned to exact version, may need updates
- First WhisperKit model run triggers CoreML compilation on ANE (~30-60s)
- RAM usage: WhisperKit ~3 GB + LLM ~2.5 GB ≈ 5.5 GB unified memory
- Whisper language hardcoded to Polish (`"pl"`) — no UI to change
- Floating indicator falls back to mouse position when the app doesn't expose AX text cursor (Electron, terminals)

## Links

- [FINDINGS.md](FINDINGS.md) — critical discoveries and workarounds from dev sessions
- [CLAUDE.md](CLAUDE.md) — detailed architecture reference and conventions
