# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-28

### Added

- Menu bar app z dyktowaniem głosowym (WhisperKit STT)
- Opcjonalne czyszczenie tekstu przez LLM (MLX Swift, Qwen3.5-4B)
- Auto-paste transkrypcji do aktywnej aplikacji
- Context-aware dictation — zaznaczony tekst jako kontekst dla LLM
- Per-app prompts z placeholderem `{{text}}`
- Globalny prompt toggle (włącz/wyłącz ogólny prompt)
- Floating pill indicator przy kursorze tekstu z poziomem audio
- Konfigurowalny hotkey (domyślnie Right ⌘, modifier-only lub combo)
- Escape anuluje nagrywanie
- Onboarding: permissions → STT model → opcjonalny LLM model
- Launch at login (SMAppService)
- Zlokalizowany UI (polski)
- 100% on-device — żadne dane nie opuszczają urządzenia

[Unreleased]: https://github.com/Nikoro/dictum/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Nikoro/dictum/releases/tag/v0.1.0
