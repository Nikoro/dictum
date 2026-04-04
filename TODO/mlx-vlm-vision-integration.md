---
title: "Integrate MLXVLM vision path when mlx-swift-lm 3.x ships"
type: feature
effort: M
status: open
scope: root
created: 2026-04-04
branch: "feat/smart-context"
commit: "920be44"
---

# Integrate MLXVLM vision path when mlx-swift-lm 3.x ships

## What

Wire the actual screenshot CGImage into the LLM inference via `ChatSession.respond(to:images:)` using the MLXVLM product. Currently the screenshot is captured but only logged as `[Screenshot captured — vision model not yet available]`. When mlx-swift-lm 3.x releases with MLXVLM and Gemma 4 vision (PR #180), enable the real image path.

## Why

This is the core of the Smart Context feature — without vision, the model can't see the screen. The entire screenshot capture infrastructure was built for this moment. Until this lands, the LLM only gets text context (app name + selected text), which limits it to basic dictation cleanup.

## Context Snapshot

We built the full smart context infrastructure on `feat/smart-context`: screenshot capture via ScreenCaptureKit, DictationContext struct, ContextGatherer, unified system prompt, and LLMProcessor accepting DictationContext. The blocker is mlx-swift-lm 2.30.6 being text-only — `ChatSession.respond(to:)` only accepts String. Version 2.31.3 was declared the last 2.x release. The 3.x main branch has already removed `swift-transformers` (resolving the WhisperKit conflict) and has MLXVLM with full vision API. Gemma 4 support is in open PR #180.

## Codebase Anchors

- `TextProcessing/LLMProcessor.swift:62` — `if context.screenshot != nil` — the TODO comment marking where to add vision path
- `TextProcessing/LLMProcessor.swift:28` — `func loadModel()` — needs to switch between `LLMModelFactory` and `VLMModelFactory` based on model type
- `Context/ScreenshotCapture.swift:8` — `func captureFrontmostWindow()` — screenshot capture already working
- `project.yml:57` — SPM dependencies — needs `MLXVLM` product added

## Plan

1. Monitor `ml-explore/mlx-swift-lm` for 3.x release with merged PR #180
2. Update `project.yml`: bump `mlx-swift-lm` to 3.x, add `product: MLXVLM` dependency
3. Verify WhisperKit 0.18.0 still resolves (3.x removes `swift-transformers`, so conflict should vanish)
4. In `LLMProcessor.swift`:
   - Import `MLXVLM` (conditionally or always)
   - Detect if loaded model is a VLM (check model config or use `VLMModelFactory`)
   - When `context.screenshot` is non-nil and model supports vision:
     ```swift
     let ciImage = CIImage(cgImage: screenshot)
     let image = UserInput.Image.ciImage(ciImage)
     result = try await session.respond(to: userMessage, images: [image])
     ```
   - Fall back to text-only path for non-VLM models
5. Consider screenshot downscaling if the model has a max input resolution
6. Update `LLMProcessor.warmup()` to include a dummy image for VLM warmup
7. Switch default model from `gemma-4-e2b-it-4bit` (text-only) to `gemma-4-e4b-it-4bit` (multimodal)

## Open Questions

- Will mlx-swift-lm 3.x have breaking API changes to `ChatSession` beyond adding image support?
- Does `VLMModelFactory` share the same `ModelContainer` type, or will `loadModel()` need separate paths?
- What's the max input resolution for Gemma 4 E4B? May need to downscale Retina screenshots (currently 2x)
