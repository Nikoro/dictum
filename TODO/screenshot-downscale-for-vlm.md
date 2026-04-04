---
title: "Add screenshot downscaling for VLM input"
type: perf
effort: S
status: open
scope: root
created: 2026-04-04
branch: "feat/smart-context"
commit: "920be44"
---

# Add screenshot downscaling for VLM input

## What

Add a resize step in `ScreenshotCapture` to downscale Retina screenshots before passing to the vision model. Currently capturing at 2x resolution (`window.frame.width * 2`) which produces large images that increase inference latency and memory usage.

## Why

A 1440x900 window at 2x = 2880x1800 pixels. Vision models typically work well at 448-1024px input resolution. Passing full Retina screenshots wastes tokens/memory and slows inference without improving the model's ability to read UI text.

## Codebase Anchors

- `Context/ScreenshotCapture.swift:22` — `config.width = Int(window.frame.width * 2)` — current 2x Retina capture
- `Context/ScreenshotCapture.swift:23` — `config.height = Int(window.frame.height * 2)` — current 2x Retina capture

## Plan

1. Research Gemma 4 E4B's optimal input resolution (likely 448x448 or 896x896 tiles)
2. After capturing, downscale to a max dimension (e.g., 1024px longest side) preserving aspect ratio
3. Use `SCStreamConfiguration` to set appropriate width/height directly (cheaper than post-capture resize)
4. Or use `CIImage` with `CIFilter.lanczosScaleTransform()` for quality downscale

## Open Questions

- What resolution does Gemma 4 E4B expect? Check the model's `preprocessor_config.json`
- Should the resolution be configurable in settings, or hardcoded based on the model?
