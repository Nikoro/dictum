# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] - 2026-04-04

### Added

- Switch default LLM to Gemma 4 with E2B/E4B/26B model options
- Bump WhisperKit to 0.18.0 and mlx-swift-lm to 2.30.6
- Fix model download flow to register model even when initial load fails
- Remove HuggingFace tag filter that silently hid new model architectures
- Redesign landing page hero with privacy pills and animated pill demo

## [0.6.1] - 2026-03-31

### Fixed

- Fix old hotkey still triggering after changing to a new hotkey

## [0.6.0] - 2026-03-30

### Added

- One-liner install script and terminal-first install UX for the landing page

### Fixed

- Preserve macOS permissions (Accessibility, Microphone) across Sparkle updates by using consistent code signing

## [0.5.1] - 2026-03-30

### Fixed

- Fix Sparkle auto-update not detecting new versions due to version comparison mismatch

## [0.5.0] - 2026-03-30

### Added

- Configurable STT language selection with per-app overrides
- Display latest release version on the landing page

### Changed

- Split PopoverView into focused single-responsibility files
- Improve safety and code quality based on audit findings

### Fixed

- Prevent enabling prompts without a downloaded LLM model
- Address privacy and model management issues from audit

## [0.4.2] - 2026-03-29

### Fixed

- Improve floating indicator pill visibility
- Fix XcodeGen pulling in non-source directories as resources

## [0.4.1] - 2026-03-29

### Changed

- Revert PKG installer, restore ZIP distribution with xattr command

### Fixed

- Point download link directly to Dictum.zip

## [0.4.0] - 2026-03-29

### Added

- Landing page with i18n support (10 languages) and GitHub Pages deployment

### Fixed

- Harden CI security: Sparkle key via temp file, SHA-256 checksum verification
- Move log file to ~/Library/Logs/Dictum/ (user-scoped, was /tmp)
- Pin WhisperKit to exact version 0.17.0 (was floating branch: main)
- Expand .gitignore for signing certificates and provisioning profiles

## [0.3.0] - 2026-03-29

### Added

- Automatic app updates via Sparkle (checks GitHub Releases on launch and every 24h)
- Full uninstall option — removes models, cache, settings, and moves app to Trash

## [0.2.0] - 2026-03-28

### Added

- App version display in menu bar footer
- STT and LLM model warm-up after load for faster first use
- App icon with proper asset registration
- Progress tracking and cancel support for model downloads

### Fixed

- App icon PNG pixel dimensions

## [0.1.1] - 2026-03-28

### Added

- Redesigned menu bar icon — rounded rectangle with mic cutout, matching app logo
- Custom accent color (purple) and app logo in UI header

### Fixed

- Use macOS 26 runner with Xcode 26 for release builds

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

[Unreleased]: https://github.com/Nikoro/dictum/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/Nikoro/dictum/compare/v0.6.1...v0.7.0
[0.6.1]: https://github.com/Nikoro/dictum/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/Nikoro/dictum/compare/v0.5.1...v0.6.0
[0.5.1]: https://github.com/Nikoro/dictum/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/Nikoro/dictum/compare/v0.4.2...v0.5.0
[0.4.2]: https://github.com/Nikoro/dictum/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/Nikoro/dictum/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/Nikoro/dictum/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Nikoro/dictum/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Nikoro/dictum/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/Nikoro/dictum/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/Nikoro/dictum/releases/tag/v0.1.0
