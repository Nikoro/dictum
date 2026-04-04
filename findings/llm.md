# LLM Processing

### [GOTCHA] [NOTE] Qwen3 emits `<think>...</think>` blocks that must be stripped
**Area:** `TextProcessing/LLMProcessor.swift`
**Tags:** `#gotcha` `#integration`
**Verified:** 2026-03-27
**Symptom:** LLM output contains chain-of-thought reasoning text before the actual cleaned transcription.
**Root cause:** Qwen3 models emit `<think>...</think>` blocks as part of their generation. `LLMProcessor.cleanText()` strips everything up to and including `</think>`. Default model changed to Gemma 4 E2B in v0.6.2, but the strip remains for users who download and use Qwen models.
**Scope:** Model-specific — if the active model doesn't emit `<think>`, the strip is a safe no-op. If a model uses different delimiters, output will be corrupted.

### [GOTCHA] [NOTE] LLMProcessor.loadModel() silently no-ops on concurrent calls
**Area:** `TextProcessing/LLMProcessor.swift`
**Tags:** `#gotcha` `#architecture`
**Verified:** 2026-04-04
**Symptom:** If two callers invoke `loadModel()` simultaneously (e.g., warmup + user-triggered load), the second call returns silently without loading.
**Root cause:** `guard !isLoading else { return }` — unlike `TranscriptionEngine` which uses task-joining (second caller awaits the in-flight load), `LLMProcessor` drops the second call entirely. Not a bug under current usage (only one call path at a time), but would break if concurrent load paths are added.
