# Polish ASR benchmark on Apple M4

## Scope

Measured locally on 2026-11-12 on Apple M4 with 32 GB unified memory and macOS 26.6.2. This is a
small reproducible comparison for Dictum, not a full leaderboard. It does not measure battery life,
conversation retention, microphone capture, streaming time after key release, or LLM cleanup.

The native model options in the desktop app now include Parakeet TDT v3, Ultra and Redux. Each has its own
cache, download status, measured storage and persisted selection. Existing installations selecting Parakeet
continue to select v3 until the user chooses another variant. Whisper remains the default. The configured
STT language is passed to the Parakeet decoder. Qwen is an experimental benchmark backend, not an app option.

## Measured results

| Runtime / model | WER | CER | RTFx | Median inference | Cached load |
| --- | ---: | ---: | ---: | ---: | ---: |
| Whisper large-v3-turbo | 3.49% | 0.89% | 2.9x | 3.286 s | 4.959 s |
| Parakeet v3 | 6.15% | 1.44% | 113.2x | 0.080 s | 0.245 s |
| Parakeet Ultra | 5.64% | 1.27% | 109.9x | 0.082 s | 0.283 s |
| Parakeet Redux | 8.00% | 1.85% | 57.7x | 0.159 s | 0.125 s |
| Qwen3-ASR 0.6B 4-bit | 32.72% | 11.33% | 25.4x | 0.371 s | 1.347 s |
| Qwen3-ASR 1.7B 4-bit | 15.49% | 6.03% | 10.6x | 0.886 s | 1.393 s |
| Qwen3-ASR 1.7B BF16 | 11.69% | 4.34% | 4.5x | 2.137 s | 2.781 s |

Whisper has the lowest observed error rate in this sample. Ultra is the practical fast alternative, with
37.3x the measured throughput of Whisper and 5.64% rather than 3.49% WER. Ultra/v3 differ by only a few
word edits, so this sample cannot establish a general accuracy winner between them. Redux trades storage
for worse measured Polish accuracy and latency here; it is not the recommended M4 choice. Qwen 1.7B BF16
improves on 4-bit but remains behind Whisper and the larger Parakeets on these clips. This does not establish
a ranking for all Qwen exports, other runtimes, or other languages. The default is unchanged.

Validation: the missing-variant regression test failed before implementation; all 65 Swift tests passed
afterward. macOS build/launch, SwiftLint, localization, comment/nesting and log-privacy checks passed.
Each native variant decoded all 50 clips twice. Dictum QA startup logs show an enabled event tap and
completed warmup. Automated native UI inspection was unavailable (`Computer Use permissions are not granted`),
so hotkey capture and switching models through the picker still need a manual interaction check.

The complete Qwen sweep includes the 1.7B BF16 export at snapshot
`e1f6c266914abc5a46e8756e02580f834a6cf8a7`, in addition to 4-bit snapshots
`313d850181767edf09f00a9c289becca70e58cd0` (0.6B) and
`78a389c776a5483b2d0d4ea5494e11012e0d6159` (1.7B).

## Corpus and protocol

- Google FLEURS `pl_pl`, `test`, Parquet conversion, file SHA-256
  `99b9ac3c34e21290bf1c7cc97715bf448f4bd30275d96b2056b18540b51a1757`.
- Fifty seeded random row indices from the 758-row split, seed `20261112`; 49 unique source utterance IDs.
- 488.94 seconds of natural read speech, 30 male and 20 female recordings. Speaker independence is not assumed.
- Original public reference text and per-file checksums are retained in the experiment manifest.
- All inputs are identical mono 16 kHz PCM, with no VAD trimming, hotword prompt, preceding text or cleanup.
- Polish is specified for every decoder. Inputs are loaded before each inference timer.
- Each model is prepared first. Native models have a separate untimed preparation process for download,
  compilation and initial prediction. Cached loading and first prediction are then measured in a fresh process.
- The same 50 files are transcribed twice sequentially per model. Quality uses only pass zero; speed uses
  all 100 measurements. Model inference never runs concurrently with another benchmark model.
- WER is corpus-level edit distance divided by reference words, with Unicode NFC, case folding,
  punctuation/symbol removal and whitespace collapsing. Polish diacritics are preserved. CER is computed
  from the same normalized strings. A secondary score spells digit tokens with Polish `num2words`.
- The report includes bootstrap uncertainty over recordings. Fifty clips do not establish performance on
  spontaneous Polish, programming vocabulary, code switching, noisy microphones or the user's own voice.

Native inference uses Dictum's real engines and pinned FluidAudio 0.18.0 / Argmax 1.1.1 through a Debug-only
benchmark entry point. Its host code is a Debug build. Qwen uses MLX Audio 0.6.5 / MLX 0.32.4 in an isolated
Python 3.12 environment. These are comparisons of these exact runtime/model combinations, not a controlled
comparison of model weights on a common implementation or a forecast of a future optimized Swift Qwen port.

Peak RSS is process memory reported by macOS, not complete system/unified memory: Core ML / ANE service
allocations and shared mapped weights are not fully attributed to the app. MLX additionally reports its own
GPU allocator peak. Cache folder sizes include runtime artifacts and are not download sizes. First-ever
preparation timings include network access, so they are not clean cold-start comparisons.

## Reproduction

The experiment is in `build/benchmarks/asr-m4-2026-11-12/`, including the manifest, source WAV checksums,
raw JSON reports, runtime versions and scoring script. Public audio is attributed to Google FLEURS,
CC BY 4.0; it is not a recording of the user.

Build with `scripts/run.sh`, then launch the Debug app with:

```sh
open -W -n /absolute/path/to/Debug/Dictum.app --args \
  --speech-benchmark /absolute/path/to/manifest.json \
  --benchmark-model parakeet-ultra --output /tmp/ultra.json
```

Use `openai_whisper-large-v3_turbo`, `parakeet-tdt-0.6b-v3`, `parakeet-ultra` or `parakeet-redux`.
Add `--benchmark-prepare-only` for the untimed preparation pass. Benchmark launch bypasses the menu bar,
event tap, normal preload and cleanup, and does not change the user's selected model or dictation settings.
Public reference transcripts are written only to the explicitly requested benchmark artifact, never `dlog`.

The Qwen equivalent is `scripts/benchmarks/speech_mlx.py --manifest ... --model ... --output ...` using
pre-downloaded `mlx-community/Qwen3-ASR-0.6B-4bit` and `mlx-community/Qwen3-ASR-1.7B-4bit`.
The tested export commits are recorded by the model cache snapshots and in the report metadata.

## Sources and additional candidates

- [FLEURS dataset and license](https://huggingface.co/datasets/google/fleurs)
- [Qwen3-ASR model family](https://huggingface.co/Qwen/Qwen3-ASR-1.7B)
- [MLX Audio inference runtime](https://github.com/Neywa-Labs/mlx-audio)
- [Native Swift Qwen3-ASR implementation](https://github.com/Neywa-Labs/mlx-audio-swift)
- [FluidAudio models](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Models.md)
- [Ultra](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/ASR/ParakeetUltra.md)
- [Redux](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/ASR/ParakeetRedux.md)

Other Polish-capable candidates include Cohere Transcribe and Nemotron Unified multilingual. They have
Core ML implementations in FluidAudio but are not measured or integrated in this experiment. English-only
Phonon-2, Bark and Nemotron Transcribe Lite are unsuitable replacements for Polish dictation. Published
benchmarks on other hardware or corpora must not be inserted into the local results table.

## Recommendation labels in desktop model lists

The model picker, initial setup and downloaded-model list share SpeechModelDetails. Whisper large-v3-turbo
is labelled Recommended: accuracy, Ultra Recommended: speed, and Redux Smaller download. Compact is not a
recommendation. v3 remains an alternative with its measured note. Other Whisper variants explicitly say that
they were not included in this Polish/M4 experiment; no measurement or recommendation is invented for them.

Rows show only the model name and its recommendation/compact badge, alongside the existing size and state
controls. Usage descriptions and benchmark figures remain in hover help. Badge hover help explains the
Polish/M4 sample, clip lengths, timing scope and limited sample; no descriptive footer is displayed. English and Polish strings are provided. No Qwen integration
or default-model change is made. Regression coverage first failed against the old single recommendation,
then all 66 Swift tests passed after the change. Build/launch, localization, SwiftLint and privacy checks
passed; QA startup confirms the event tap and warmup. Visual inspection remains unavailable because native
Computer Use permissions are not granted. No additional TestFlight or macOS release was published.
