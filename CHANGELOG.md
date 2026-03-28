# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-28

### Added

- Menu bar voice dictation app (WhisperKit STT)
- Optional LLM text cleanup (MLX Swift, Qwen3.5-4B)
- Auto-paste transcription into the active window
- Context-aware dictation — selected text as LLM context
- Per-app prompts with `{{text}}` placeholder
- General prompt toggle (enable/disable default prompt)
- Floating pill indicator at text cursor with audio level
- Configurable hotkey (default: Right ⌘, modifier-only or combo)
- Escape cancels recording
- Onboarding flow: permissions → STT model → optional LLM model
- Launch at login (SMAppService)
- Localized UI (Polish)
- 100% on-device — no data leaves the device

[Unreleased]: https://github.com/Nikoro/dictum/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Nikoro/dictum/releases/tag/v0.1.0
