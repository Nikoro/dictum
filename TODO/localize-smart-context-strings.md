---
title: "Localize new Smart Context UI strings"
type: debt
effort: XS
status: open
scope: root
created: 2026-04-04
branch: "feat/smart-context"
commit: "920be44"
---

# Localize new Smart Context UI strings

## What

Add Polish and English translations for the new strings introduced in the Smart Context feature: Screen Recording permission row, unified prompt section header/reset button, and the renamed "Additional instructions" label.

## Why

The app is localized (en.lproj + pl.lproj). New UI strings use `String(localized:defaultValue:)` with English defaults but need proper .strings entries for both languages.

## Codebase Anchors

- `MenuBar/SetupView.swift` — `setup.step1.screen.title`, `setup.step1.screen.desc`
- `MenuBar/LLMModelSection.swift` — `section.prompt.unified`, `section.prompt.unified.reset`, updated `section.prompt.general`
- `Resources/en.lproj/Localizable.strings` — English strings file
- `Resources/pl.lproj/Localizable.strings` — Polish strings file

## Plan

1. Add to `en.lproj/Localizable.strings`: Screen Recording, System prompt, Reset, Additional instructions
2. Add to `pl.lproj/Localizable.strings`: Polish translations for the same keys
3. Update all 10 language files in `website/i18n/` if the landing page references these features
