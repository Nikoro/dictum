# Implementation constraints

Constraints and usage notes that cannot be inferred from code. Source files keep only the short local notes allowed by commit_gate.

## [Shared/Audio/RecordingSink.swift](../Shared/Audio/RecordingSink.swift)

- AVAudioEngine calls write on its audio thread; the lock protects every access to the file and error, including closing the file before transcription starts.

## [iOS/App/ModelPreparation.swift](../iOS/App/ModelPreparation.swift)

- FluidAudio 0.18 assigns half of each package's progress to compilation. Show its byte progress as a package download, never as total model preparation.

## [macOS/Audio/AudioRecorder.swift](../macOS/Audio/AudioRecorder.swift)

- @unchecked Sendable holds because capture setup, `isRecording` and `audioLevel` are only touched on the main actor, conversion only on `drainQueue`, and `audioBuffer` only under `bufferLock`.

- preparing binds and initializes the input unit without starting it, so the microphone stays off (no privacy indicator) yet the next start skips device setup.

- a device that disappears or changes its sample rate mid-recording (a Bluetooth headset switching profiles) leaves the bound unit silent; the capture is rebuilt on the current device and the samples recorded so far are kept.

## [macOS/Audio/HALInputCapture.swift](../macOS/Audio/HALInputCapture.swift)

- single producer (the real-time render thread) and single consumer (the drain queue); the render thread must not allocate or lock, so samples go through fixed storage and atomics.

- AVAudioEngine follows the system default input and re-resolves it on every configuration change, so a chosen microphone was dropped and each start waited for the engine to settle. An AUHAL bound to one device and initialized ahead of time starts in milliseconds.

- the input side of AUHAL converts formats but not sample rates, so the client format keeps the device rate; channel map 0 takes the first channel of multi-channel inputs.

## [macOS/Audio/SpeechSampleConverter.swift](../macOS/Audio/SpeechSampleConverter.swift)

- one AVAudioConverter per recording keeps its filter state between chunks, so chunk borders do not click; it is not thread-safe and is only used on the recorder's drain queue.

- the block runs synchronously inside `convert`, so the flag is never shared across threads; handing the same buffer back twice would duplicate audio.

## [macOS/Audio/SpeechTrimmer.swift](../macOS/Audio/SpeechTrimmer.swift)

- Whisper hallucinates text ("Dziękuję.", subtitles credits) on long silent tails and on speechless recordings, so silence is cut and speechless audio is dropped entirely.

## [macOS/Context/ContextGatherer.swift](../macOS/Context/ContextGatherer.swift)

- screenshot and clipboard only feed the LLM, so they are skipped without it. Selected text is not: it decides whether the result is copied instead of pasted over it.

- NSRunningApplication is not Sendable and the frontmost app may change mid-dictation, so the target is snapshotted into this value at recording start.

- the clipboard is read first and synchronously, before the pipeline's own paste starts mutating it.

## [macOS/Context/ScreenshotCapture.swift](../macOS/Context/ScreenshotCapture.swift)

- `pid` must be the app frontmost when recording started; by the time this runs something else may be in front.

## [macOS/Context/ScreenshotOCR.swift](../macOS/Context/ScreenshotOCR.swift)

- Vision throws on an unsupported language, and it supports fewer languages than Whisper transcribes.

## [macOS/DictationPipeline.swift](../macOS/DictationPipeline.swift)

- cancel the work itself, or transcription and generation keep the GPU busy after the pill has disappeared.

- a key-up can be lost (e.g. the tap was disabled mid-press); stop and transcribe rather than record forever.

## [macOS/DictationProcessor.swift](../macOS/DictationProcessor.swift)

- without context the output is a cleanup of the input, so a result shrunk below 30% means the model answered or refused instead of cleaning; commands with context may legitimately produce something shorter.

- the context is returned even without LLM cleanup, because a selection means "copy the result" rather than paste over it.

## [macOS/DictumApp.swift](../macOS/DictumApp.swift)

- unit tests run inside the app as their host; starting the event tap, the menu bar and model preloading there would race the tests and prompt for permissions.

## [macOS/DictumLogger.swift](../macOS/DictumLogger.swift)

- log() must never block its caller; it is called from the event tap callback, and a slow callback makes macOS disable the tap.

- messages are public in the unified log because dlog never carries dictated content (enforced by scripts/quality/check_log_privacy.py); the category is the "[Tag]".

## [macOS/FloatingIndicator/FloatingIndicatorView.swift](../macOS/FloatingIndicator/FloatingIndicatorView.swift)

- hop to the main actor explicitly; annotating the @Sendable Timer block with @MainActor silently drops the isolation.

## [macOS/HotkeyAndPaste/ClipboardPasteController.swift](../macOS/HotkeyAndPaste/ClipboardPasteController.swift)

- the target app reads the pasteboard asynchronously after Cmd+V; restoring the user's clipboard sooner pastes their old contents instead.

- the nspasteboard.org markers tell clipboard managers to skip this entry, so every dictation does not land in the user's clipboard history.

## [macOS/HotkeyAndPaste/GlobalHotkeyMonitor.swift](../macOS/HotkeyAndPaste/GlobalHotkeyMonitor.swift)

- without invalidation the mach port outlives the tap, and start() rebuilds the tap often.

- macOS disables a tap whose callback is slow, or on some user input. Unless it is re-enabled, the hotkey silently stays dead until the app restarts.

- capturing the selection may post Cmd+C and wait for it, which would stall the event tap, so it runs detached.

## [macOS/HotkeyAndPaste/PasteboardSnapshot.swift](../macOS/HotkeyAndPaste/PasteboardSnapshot.swift)

- if the user copied something after `changeCount` was taken, putting the old contents back would silently destroy their copy.

## [macOS/HotkeyAndPaste/SelectedTextCapture.swift](../macOS/HotkeyAndPaste/SelectedTextCapture.swift)

- never call this on the event tap thread; the synthetic Cmd+C is delivered through that thread, so blocking it here would wait forever.

## [macOS/MenuBar/MenuBarIcon.swift](../macOS/MenuBar/MenuBarIcon.swift)

- the cutout must be a CGImage drawn with destinationOut; NSImage.draw does not punch through. Centering uses the symbol's alignment rect, not its full bounds.

## [macOS/MenuBar/PreferenceRow.swift](../macOS/MenuBar/PreferenceRow.swift)

- a popup Picker keeps its intrinsic width inside a wider frame and centers itself, so the control frame is trailing-aligned to keep every row's right edge on one line.

## [macOS/MenuBar/UnifiedPromptSection.swift](../macOS/MenuBar/UnifiedPromptSection.swift)

- store only a real override. The editor is seeded with the default, and saving that verbatim would freeze the user on today's wording.

## [macOS/ModelBrowser/HuggingFaceModelSearch.swift](../macOS/ModelBrowser/HuggingFaceModelSearch.swift)

- URLComponents, not manual percent-encoding; `.urlQueryAllowed` lets `&` and `=` through, so a query could inject extra parameters.

## [macOS/ModelBrowser/LLMModelStorage.swift](../macOS/ModelBrowser/LLMModelStorage.swift)

- models downloaded before swift-transformers 1.2 live in ~/Library/Caches/models as plain <org>/<name> folders; newer ones in a Hub-layout cache next to them. Both stay usable, so an upgrade never re-downloads gigabytes. The shared ~/.cache/huggingface is deliberately not used: other tools' models there would show up in, and be deleted from, Dictum.

- swift-transformers 1.1 fetched no chat_template.jinja and worked without it; 1.2+ refuses to apply a chat without one, so old folders need their sidecar files topped up.

- a complete local copy is used without touching the network, so a model loads offline and app launch does not depend on huggingface.co being reachable.

## [macOS/Settings/AppSettings.swift](../macOS/Settings/AppSettings.swift)

- Observation cannot see UserDefaults, so every stored read touches `revision` and every write bumps it. (@AppStorage is no fix: it only publishes binding writes.)

- older builds stored the default verbatim. An outdated copy never mentions the OCR block, so the model reproduces the screen text instead of following the command.

## [macOS/Settings/DefaultPrompts.swift](../macOS/Settings/DefaultPrompts.swift)

- the settings UI once stored the default just for being opened, so a stored prompt equal to one of these was never the user's own and is safe to clear.

## [macOS/Settings/DictationPreferenceTypes.swift](../macOS/Settings/DictationPreferenceTypes.swift)

- English stays as a fallback because window chrome is usually English, whatever language the user dictates in.

## [macOS/Settings/FileManagerExtensions.swift](../macOS/Settings/FileManagerExtensions.swift)

- Hugging Face cache snapshots are symlinks into blobs/; counting them as well would report every model at twice its size.

## [macOS/Settings/SparkleUpdateController.swift](../macOS/Settings/SparkleUpdateController.swift)

- a Debug build has build number 1, so Sparkle sees every release as newer and installs it over the build output; development builds must never start the updater.

## [macOS/Settings/SystemPermissionStore.swift](../macOS/Settings/SystemPermissionStore.swift)

- kAXTrustedCheckOptionPrompt is imported as a mutable global, which Swift 6 refuses to read; its value is a constant string.

- macOS shows the microphone prompt only once; after a denial the only way back is System Settings.

- the block must ignore its Timer argument (not Sendable); invalidation goes through `pollingTimer`. Scheduled from the main actor, so assumeIsolated is safe.

## [macOS/TextProcessing/LLMModelDownloadController.swift](../macOS/TextProcessing/LLMModelDownloadController.swift)

- select the model only after it loaded, or a failed download leaves a selected model that does not exist on disk.

## [macOS/TextProcessing/LLMProcessor.swift](../macOS/TextProcessing/LLMProcessor.swift)

- concurrent calls for the same model share one load, so only the first caller's progressHandler reports.

- a call for another model must wait and load its own, never return early; callers treat a clean return as "this model is ready".

- a screenshot changes the prompt's token layout, so image requests always prefill from scratch through ChatSession instead of the cached text prefix.

- warming with the real prompt and a sentence-sized input also prefills the cached system prompt, so the first dictation pays neither shader compilation nor that prefill.

- GPU work still queued would keep buffers alive past the release, so the stream is drained first and the cache limit dropped to zero while the model is freed.

## [macOS/TextProcessing/LLMPrompting.swift](../macOS/TextProcessing/LLMPrompting.swift)

- the output is a cleaned or rewritten version of the input, so its length tracks the input; a fixed large budget only lets a looping model run for a long time.

- speculative decoding with Gemma 4's MTP drafter produced identical output at temperature 0 and roughly halved generation time on dictation-length text.

## [macOS/TextProcessing/PromptPrefixCache.swift](../macOS/TextProcessing/PromptPrefixCache.swift)

- only touched inside ModelContainer.perform, which serializes access, so the non-Sendable KV arrays are never shared across threads.

- Gemma 4's sliding-window cache cannot be trimmed back once used, so the prefilled prefix is kept pristine and every generation continues from a copy of it.

- MTP drafters hold no target-derived state and are documented as safe to share across iterators; the box only carries the non-Sendable model into ModelContainer.perform.

## [macOS/Transcription/DebugTranscriptionHarness.swift](../macOS/Transcription/DebugTranscriptionHarness.swift)

- debug-only entry point, so the STT path can be verified without a microphone. `Dictum --transcribe-file a.wav --output out.txt [--language pl|auto] [--cleanup [--clipboard text]]`, or `Dictum --llm-text "transcript" --output out.txt [--screenshot window.png [--ocr-only]] [--prompt-file p.txt]` for the LLM alone.

## [macOS/Transcription/LLMBenchmark.swift](../macOS/Transcription/LLMBenchmark.swift)

- debug-only benchmark of the plain ChatSession path against the cached-prefix path (and an MTP drafter) at temperature 0, so outputs must match exactly.

## [macOS/Transcription/LiveChunkTranscriber.swift](../macOS/Transcription/LiveChunkTranscriber.swift)

- the poll sleep is cancelled on finish so key-up never waits for it, while a chunk already being transcribed runs in its own task and is awaited, not cancelled with the loop.

- cutting mid-word garbles both halves, so a chunk ends in the last pause after the minimum length; only a pause-free stretch is cut hard, below Whisper's 30 s window.

## [macOS/Transcription/ModelWarmupCoordinator.swift](../macOS/Transcription/ModelWarmupCoordinator.swift)

- the first inference compiles Metal shaders and takes seconds, so a dummy one runs right after loading instead of during the user's first dictation.

- loading starts with the recording, so a model unloaded while idle is usually back before the user stops talking.

## [macOS/Transcription/TranscriptionEngine.swift](../macOS/Transcription/TranscriptionEngine.swift)

- join an in-flight load only for the same model; a different model's load must not be reported as ours.

- with `language: nil` WhisperKit skips detection and decodes as English unless `detectLanguage` is set. Without timestamps it also cuts audio past one 30 s window mid-word, so longer audio keeps timestamps and is split at pauses instead.

## [macOS/Transcription/TranscriptionPrompt.swift](../macOS/Transcription/TranscriptionPrompt.swift)

- WhisperKit feeds prompt tokens through the decoder one step at a time (~70 ms each), so a fresh dictation gets no prompt; a later chunk of a long recording gets the tail of the previous one, which keeps casing and wording consistent across the cut.

## [macOS/Transcription/WhisperModelStorage.swift](../macOS/Transcription/WhisperModelStorage.swift)

- WhisperKit defaults to ~/Documents/huggingface. macOS guards Documents per code signature, so every re-signed release lost access and could not even read its own models; downloads now live next to the LLM models instead.

## [macOS/Transcription/WhisperModelStore.swift](../macOS/Transcription/WhisperModelStore.swift)

- CoreML compilation reports no progress, so the second half of the bar creeps towards 99% over the typical ~120 s instead.

- the block must ignore its Timer argument (not Sendable, so reaching it from the main actor is a cross-isolation send); `defer` invalidates instead. Scheduled from the main actor, the block runs on the main run loop, which makes assumeIsolated safe.

## [scripts/benchmarks/speech_mlx.py](../scripts/benchmarks/speech_mlx.py)

- Measure cached Qwen3-ASR inference on the same manifest as Dictum's native harness.

## [scripts/hooks/commit-msg](../scripts/hooks/commit-msg)

- Dictum commit-msg hook: every fix commit ships a passing regression test.

## [scripts/hooks/install.sh](../scripts/hooks/install.sh)

- Points git at the versioned hooks in scripts/hooks. Idempotent; run once per clone.

## [scripts/hooks/pre-commit](../scripts/hooks/pre-commit)

- Dictum pre-commit hook. Blocks the commit on any finding; gates and thresholds are described in docs/quality-gates.md. Do not bypass with --no-verify.

## [scripts/quality/check_all.sh](../scripts/quality/check_all.sh)

- Runs every pre-commit gate over the whole repository instead of the staged files.

## [scripts/quality/check_comments.py](../scripts/quality/check_comments.py)

- Code explains itself: fail on any Swift comment that is not one of - a tool directive: `swiftlint:`, `swiftformat:`, `sourcery:` - a `TODO:` / `FIXME:` with enough context to act on - an `// Edge case:` note of at most 4 lines, stating what the code cannot say on its own: a platform quirk, an ordering dependency, why the obvious simpler version is wrong. Doc comments (`///`, `/** */`), `MARK:` banners, narration and trailing remarks all fail. Usage: check_comments.py FILE...

## [scripts/quality/check_log_privacy.py](../scripts/quality/check_log_privacy.py)

- Fail when a dlog(...) call interpolates something that may carry dictated content. dlog lines go to a file and to the unified log as public text, so they may contain only counts, flags, ids and durations. Interpolating a value whose name suggests text (transcript, prompt, clipboard, selection, OCR, output...) is rejected unless it is reduced to `.count`, a nil or empty check, or an explicitly content-free summary. Usage: check_log_privacy.py FILE...

## [scripts/quality/check_nesting.py](../scripts/quality/check_nesting.py)

- Fail when a Swift file nests braces deeper than the limit (default 6). Usage: check_nesting.py [--max N] FILE...

## [scripts/quality/check_regression_test.sh](../scripts/quality/check_regression_test.sh)

- commit-msg gate: a fix commit must ship a regression test, and the tests must pass. A fix commit is one whose subject starts with fix:, fix(scope):, bug:, hotfix: or the Polish napraw:/naprawia: (optional `!`). When it stages app Swift code, it must also add or modify a test in the mirror location of the fixed file: Transcription/WhisperModelStorage.swift → DictumTests/Transcription/WhisperModelStorageTests.swift Existing file: add the case to it. Missing file: create it. Write the test first and watch it fail (red), then fix the code (green), then refactor. The gate then runs the whole suite. A fix that stages no app Swift code (website, workflow, scripts, strings) is skipped: there is no Swift test that could reproduce it, and an unrelated one would only appease the hook.

## [scripts/quality/check_strings.py](../scripts/quality/check_strings.py)

- Localization gate for Resources/*.xcstrings. Fails when a catalog is not valid JSON, a key lacks a translated English or Polish value (including every plural form), the code uses a key the catalog lacks (the UI would fall back to the English default even in Polish), or the catalog carries a key no code references.

## [scripts/quality/lizard.sh](../scripts/quality/lizard.sh)

- Cognitive complexity gate (SonarSource metric, via Lizard) for the given Swift files. SwiftLint covers cyclomatic complexity but has no cognitive complexity rule; Lizard's own nesting-depth metric is not used because it counts every `case` of a Swift `switch` as a level. Lizard is not in Homebrew (`brew install lizard` is an unrelated compressor), so it is installed on first use into a project-local venv at .tools/lizard, pinned below. Usage: scripts/quality/lizard.sh FILE...

- -w prints only functions over a threshold and exits non-zero if there are any. The default CCN and length thresholds are raised out of the way; SwiftLint already enforces both.

## [scripts/quality/swift_lexer.py](../scripts/quality/swift_lexer.py)

- Minimal Swift lexer for the quality gates: finds comments and code braces, skipping string literals (including multi-line literals and `\(...)` interpolations).

- Yields Comment and Brace tokens in source order.

## [scripts/run.sh](../scripts/run.sh)

- Kills the running Dictum, builds Debug, launches the fresh build and confirms it stays up. Usage: scripts/run.sh [--no-launch]

## [scripts/signing/sign_sparkle_helpers.sh](../scripts/signing/sign_sparkle_helpers.sh)

- Xcode signs the embedded Sparkle.framework but not the helper tools nested inside it, which keep Sparkle's own signature and fail notarization. Re-signs them, innermost first, with our identity; Xcode then seals the app around them. Order and flags follow Sparkle's docs.

## [scripts/test.sh](../scripts/test.sh)

- Runs the DictumTests unit tests; prints only the failures. Usage: scripts/test.sh

## [website/install.sh](../website/install.sh)

- Dictum installer — downloads the latest notarized release and installs it to /Applications.

- Create temp directory

- Download latest release

- Extract

- Remove old version if present

- Move to Applications

## [macOS/Settings/DefaultPrompts.swift](../macOS/Settings/DefaultPrompts.swift)

- An older settings UI stored the default prompt merely by being opened. Stored prompts matching a superseded default can therefore be cleared safely; they are not user-authored prompts.
