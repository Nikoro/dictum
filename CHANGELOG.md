# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Host-app return waits for the Dictum scene to become active before starting audio and returning; cancelled or timed-out requests cannot redirect later

- Empty iOS recordings and recognition results return to readiness without an error or inserted text
- Keyboard errors show their full text, can be dismissed, and clear when starting another attempt

### Added

- Consistent desktop model recommendations for Polish accuracy/speed, compact-download labels and scoped M4 benchmark notes
- Desktop Parakeet Ultra and Redux options with independent download/storage/selection and configured language hints
- Reproducible M4 Polish ASR benchmark harness and MLX Qwen comparison runner
- Dictus-based communication and AI host catalogue, including Claude, Gemini, Gmail, Signal, Messenger and Telegram
- Native iPad key layout with Tab, separate Caps Lock, both Shift keys, auxiliary flick characters and a keyboard-dismiss control
- Three-row iPad emoji browser with dedicated emoji and system keyboard-switch controls
- Guarded Dictus-style host discovery and automatic return after microphone-session readiness on physical iOS devices
- Keyboard language hints for local iOS transcription, reducing Latin/Cyrillic confusion in both Parakeet models
- Long-press frequent emoji shortcuts with persistent usage counts and touch tracking outside the popup
- Caps Lock by double-tapping Shift
- Simulator-only keyboard comparison host with black and colored backgrounds

### Changed

- TestFlight candidate 0.11.0 (26111302) includes the latest iPhone layout and keyboard error handling

- iPhone Return matches backspace width, allocating the recovered width to space; iPad layout is unchanged
- Phone keyboard key planes bottom-align within surplus input-view height instead of leaving extra space below the last row
- iOS build 26111301 retains 0.11.0 and is available to the Internal TestFlight group after a fresh upload
- Compact desktop speech-model rows show names and recommendation badges; descriptions and benchmark notes move to hover help
- UIKit keyboard touch dispatcher preserves simultaneous touches and routes gap taps to the closest key
- Letter and modifier controls are reused while typing; touch handling runs outside the SwiftUI keyboard layout
- Local iOS build 26111206 expands app return targets without a TestFlight upload
- Local iOS build 26111205 retains version 0.11.0 and is not uploaded to TestFlight
- Five-row horizontal emoji categories, native-reference emoji glyphs and calibrated key/material colors
- Dictum key matches the other keys' height; recording uses a red rounded rectangle on a normal key
- Accent popup width and ordering match the native O reference; popup spacing is reserved only when needed
- Local build 26111204 retains version 0.11.0; subsequent TestFlight uploads require explicit permission

## [0.11.0] - 2026-11-12

### Added

- iOS keyboard emoji browser with eight categories, English and Polish search, recent emoji, and skin-tone variants
- Horizontal long-press accent selection with European letter variants, including umlauts, and selection while dragging outside the popup

### Changed

- iOS keyboard key geometry and return width calibrated against the native keyboard on the same Simulator, with a dedicated 50-point Dictum slot
- iOS model preparation shows progress, elapsed time, approximate download size and actual stored size
- iOS microphone state is shown by the toolbar icon without a duplicate idle status row
- TestFlight builds keep the current semantic version until explicitly changed and increment BirthMinder's date-based build counter
- iOS model selection lists both models with selection indicators, installed status and measured storage
- iOS app footer displays the installed semantic version and build number
- Tapping outside the iOS test editor dismisses the keyboard without intercepting model buttons
- Keyboard activation links resume a paused microphone without a second tap; unused sessions stop after five minutes

## [0.10.3] - 2026-10-31

### Fixed

- The microphone started recording only about two seconds after the hotkey, so the beginning of a sentence, or a whole short one, was lost; it now records within a fraction of a second
- The chosen microphone was dropped for the system default (often a Bluetooth headset), and switching microphones could crash Dictum
- Transcription took about a second longer than needed after every dictation

## [0.10.2] - 2026-10-31

### Fixed

- A crash while recording in 0.10.1: releases were compiled with an older Xcode than the one Dictum is developed and tested with, and are now built with the same one

## [0.10.1] - 2026-10-31

### Fixed

- Dictation stopped working after updating to 0.10.0: the speech model sat in the Documents folder, which macOS locked for the newly signed app. Models now live in Dictum's own folder; existing ones are moved there once (macOS asks for Documents access) or downloaded again if access is denied
- Deleting a Whisper model left its files on disk, and the size shown for it was an estimate instead of the real one
- Uninstall now also removes the Whisper and Parakeet models

## [0.10.0] - 2026-10-30

> Dictum is now signed with a Developer ID and notarized by Apple. The signature changed, so
> macOS asks for Microphone and Accessibility once more after this update (System Settings →
> Privacy & Security → Accessibility: remove the old Dictum entry and enable the new one). Later
> updates keep the permissions.

### Added

- Developer ID signature and Apple notarization: the app opens without Gatekeeper warnings or the quarantine workaround
- Live transcription: long dictations are decoded at pauses while you speak; 48 s of speech is ready about 5.5 s after key-up instead of ~17 s
- Parakeet TDT v3, a many-times-faster speech model, in the same list as the Whisper models
- Microphone picker, word replacement dictionary, and unloading models after a chosen idle time

### Changed

- LLM cleanup is about twice as fast with identical output (cached system prompt, Gemma 4 speculative decoding)
- Latest WhisperKit, MLX, swift-transformers and Sparkle; models downloaded earlier keep working
- LLM models are stored only in Dictum's own folder, each listed once; other tools' Hugging Face models no longer appear
- Settings rows are aligned with consistent labels
- Split the dictation pipeline into smaller parts and adopted Observation

### Fixed

- Bluetooth headsets left every recording empty (A2DP → HFP switch)
- "Auto" language transcribed Polish speech as English
- Silence, or holding the hotkey without speaking, pasted invented text
- Switching the Whisper model only took effect after a restart
- Missing Polish translations in several sections
- The published app's signature was broken by zip packaging

## [0.9.0] - 2026-07-26

### Changed

- Update WhisperKit to 1.0.0, now part of the Argmax OSS SDK
- Build the app in Swift 6 language mode

### Fixed

- Opening the prompt settings once silently froze the system prompt on its wording at that moment, so later improvements never reached it. A prompt saved before OCR existed left the model with a large block of screen text it had no instructions for, making it reproduce that text instead of following a spoken command

## [0.8.0] - 2026-07-25

### Added

- Smart context: dictation can use a screenshot of the active window, on-screen text via OCR, the current selection, and the clipboard
- Vision model support — MLXVLM wired up so VLM models can see the captured screenshot
- Per-source context toggles for screenshot, selection and clipboard
- Separate feedback while the LLM is processing

### Changed

- Prioritize the screenshot over the clipboard when both are available
- Move prompt settings into the main popover
- Split UI modules and separate runtime state from the dictation pipeline

### Fixed

- The global hotkey silently stopped working once macOS disabled the event tap; the tap is now re-enabled, and logging no longer blocks its callback
- Switching STT or LLM models while another load was in flight returned the previous model and reported success
- A failed LLM download adopted the model anyway without surfacing an error
- Screenshot context captured whichever app was frontmost at capture time instead of the app dictation started in
- Escape now cancels transcription and LLM generation instead of only hiding the indicator
- Dictated text and LLM output are no longer written to the debug log
- Settings changed outside the settings UI now refresh it
- OCR recognition languages follow the selected STT language
- Floating indicator anchor resolution

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

[Unreleased]: https://github.com/Nikoro/dictum/compare/v0.10.3...HEAD
[0.10.3]: https://github.com/Nikoro/dictum/compare/v0.10.2...v0.10.3
[0.10.2]: https://github.com/Nikoro/dictum/compare/v0.10.1...v0.10.2
[0.10.1]: https://github.com/Nikoro/dictum/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/Nikoro/dictum/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/Nikoro/dictum/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/Nikoro/dictum/compare/v0.7.0...v0.8.0
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
