---
title: "Add fast-path toggle to skip screenshot/vision for pure dictation"
type: feature
effort: S
status: open
scope: root
created: 2026-04-04
branch: "feat/smart-context"
commit: "920be44"
---

# Add fast-path toggle to skip screenshot/vision for pure dictation

## What

Add an optional toggle in settings that skips screenshot capture and vision inference entirely. When enabled, the pipeline goes straight from transcript to text-only LLM cleanup — no ScreenCaptureKit call, no image in the prompt. This is priority item #5 from the spec.

## Why

Users who only want dictation cleanup (no contextual commands) pay unnecessary latency for screenshot capture + larger prompt. The fast path should be as fast as the pre-smart-context pipeline.

## Codebase Anchors

- `DictationPipeline.swift:278` — `let context = await ContextGatherer.gather(...)` — the context gathering call that would be skipped
- `Settings/AppSettings.swift` — where the toggle would be added
- `MenuBar/LLMModelSection.swift` — where the toggle UI would go

## Plan

1. Add `@AppStorage("smartContextEnabled") var smartContextEnabled: Bool = true` to `AppSettings`
2. In `DictationPipeline.stopRecordingAndProcess()`: if `!settings.smartContextEnabled`, skip `ContextGatherer.gather()` and pass `context: nil` to `LLMProcessor.cleanText()`
3. Add a toggle in `LLMModelSection` near the unified prompt section
4. When disabled, the unified prompt still applies but without screenshot/app context in the user message

## Open Questions

- Should this also skip selected text capture, or only screenshot? Selected text capture is synchronous in the event tap and near-zero cost
