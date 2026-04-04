# Transcription & Audio

### [GOTCHA] [CRITICAL] WhisperKit model download state not persisted on disk
**Area:** `Transcription/WhisperModelManager.swift`
**Tags:** `#gotcha` `#integration`
**Verified:** 2026-03-26
**Symptom:** After every app rebuild, setup screen asks to download the STT model again even though it was already downloaded.
**Root cause:** WhisperKit doesn't store models in a scannable disk location. The original `scanDownloaded()` checked HuggingFace cache dirs (`~/Library/Caches/huggingface/`, `~/.cache/huggingface/`) but found nothing — WhisperKit manages its own cache internally.
**Workaround:** Persist downloaded model IDs in `UserDefaults` (`whisperDownloadedModelIds` key) after successful `loadModel()`. Don't rely on filesystem scanning.
**Note:** This applies only to STT (WhisperKit) models. LLM models (MLX) *are* disk-scanned via `DownloadedModelsManager` at `~/Library/Caches/models/mlx-community/`.

### [GOTCHA] [CRITICAL] Whisper hallucinates on short audio when model loads lazily
**Area:** `DictationPipeline.swift`
**Tags:** `#gotcha` `#architecture`
**Verified:** 2026-03-26
**Symptom:** User says "raz dwa trzy" but Whisper transcribes "Dziękuję." every time.
**Root cause:** STT model loaded lazily after `stopRecording()`. Loading takes ~5s, during which no audio is captured. Result: only ~2.5s of audio (40960 samples at 16kHz), often too short/quiet for Whisper, triggering hallucination of common Polish phrases.
**Workaround:** Preload STT model at app startup (`preloadSTTModel()` in `DictationPipeline.init`) so it's ready before first recording.
