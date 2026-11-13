# Architecture

- `DictumApp` calls `DictationPipeline.shared.start()` at launch; nothing else creates the
  pipeline, so without that call the hotkey is never registered.
- A new `@Observable` store read by views must be injected in `MenuBarController.setupPopover`,
  or the popover crashes when opened.
- The CGEvent tap callback must stay fast: macOS disables a slow tap and the hotkey dies. No I/O,
  per-event logging or waiting on that path.
- No transcription history is stored, by design.
- Uninstall deletes the shared MLX cache root, not only Dictum-owned models.
- Whisper stays the default engine. Desktop Parakeet variants have separate persisted selections and caches;
  see [the M4 Polish ASR benchmark](asr-benchmark.md) for the measured quality/speed tradeoff.
- LLM cleanup runs at temperature 0 through a cached system-prompt prefix plus Gemma 4's MTP
  drafter. On five Polish transcripts this matched plain `ChatSession` output exactly and took
  0.96 s on average instead of 1.78 s; requests with a screenshot still use `ChatSession`.
- Apple Foundation Models is not an alternative backend: it does not support Polish.
- Live chunking (`LiveChunkTranscriber`) settled on 8 s minimum chunks and a 60-character
  preceding-text prompt: longer prompts are decoded token by token and made each chunk slower.
