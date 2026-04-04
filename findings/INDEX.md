# Findings Index

| File | Area | Findings | Last Updated |
|------|------|----------|--------------|
| [audio.md](audio.md) | Transcription & Audio | 3 | 2026-04-04 |
| [ui.md](ui.md) | UI & Rendering | 3 | 2026-03-26 |
| [llm.md](llm.md) | LLM Processing | 2 | 2026-04-04 |
| [settings.md](settings.md) | Settings & Persistence | 1 | 2026-03-28 |
| [hotkey.md](hotkey.md) | Paste & Hotkey | 3 | 2026-04-04 |
| [tooling.md](tooling.md) | Tooling & CI | 3 | 2026-04-04 |
| [models.md](models.md) | Model Browser & Downloads | 3 | 2026-04-04 |
| [dependencies.md](dependencies.md) | Dependencies | 1 | 2026-04-04 |

## All Finding Titles

### audio.md
- [GOTCHA] [CRITICAL] WhisperKit model download state not persisted on disk
- [GOTCHA] [CRITICAL] Whisper hallucinates on short audio when model loads lazily
- [GOTCHA] [NOTE] WhisperModelManager download progress 50%–99% is fabricated

### ui.md
- [GOTCHA] [GOTCHA] `.background(.ultraThinMaterial)` kills `.glassEffect()` rendering
- [GOTCHA] [NOTE] TimelineView reconstructs child views — onAppear fires repeatedly
- [GOTCHA] [NOTE] @Published changes don't propagate across NSPanel window boundary

### llm.md
- [GOTCHA] [NOTE] Qwen3 emits `<think>...</think>` blocks that must be stripped
- [GOTCHA] [NOTE] LLMProcessor.loadModel() silently no-ops on concurrent calls

### settings.md
- [NOTE] [NOTE] llmDownloadedModelId is a one-way write — never cleared on model deletion

### hotkey.md
- [BUG] [GOTCHA] CGEvent paste requires `.cgAnnotatedSessionEventTap`
- [GOTCHA] [NOTE] SelectedTextReader.readSelectedText() must never run on event tap's run loop thread
- [GOTCHA] [NOTE] GlobalHotkeyManager uses nonisolated(unsafe) cache — safe only under current usage

### tooling.md
- [BUG] [CRITICAL] AppIcon silently dropped when PNGs have wrong pixel dimensions
- [GOTCHA] [CRITICAL] GitHub Actions macos-15 runner defaults to Xcode 16 — mlx-swift-lm fails to compile
- [GOTCHA] [GOTCHA] Claude Code Write tool double-escapes backslashes in .strings files

### models.md
- [BUG] [GOTCHA] HuggingFace model tag filter silently hides new model architectures
- [GOTCHA] [CRITICAL] mlx-swift-lm 2.x does not support Gemma 4 — "unsupported model type"
- [BUG] [GOTCHA] downloadLLMModel coupled download and load — failed load prevented model registration

### dependencies.md
- [GOTCHA] [GOTCHA] mlx-swift-lm 2.31.3 incompatible with WhisperKit 0.18.0 — swift-transformers version conflict
