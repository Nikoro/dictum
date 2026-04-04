# LLM Processing

### [GOTCHA] [NOTE] Qwen3 emits `<think>...</think>` blocks that must be stripped
**Area:** `TextProcessing/LLMProcessor.swift`
**Tags:** `#gotcha` `#integration`
**Verified:** 2026-03-27
**Symptom:** LLM output contains chain-of-thought reasoning text before the actual cleaned transcription.
**Root cause:** Qwen3 models (including Qwen3.5-4B-4bit) emit `<think>...</think>` blocks as part of their generation. `LLMProcessor.cleanText()` strips everything up to and including `</think>`.
**Scope:** Model-specific — if switching to a non-Qwen model that doesn't emit `<think>`, the strip is a safe no-op. If switching to a model that uses different delimiters, output will be corrupted.
