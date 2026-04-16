# Project Audit Report

**Audited**: Dictum | **Date**: 2026-04-15 | **Type**: Swift 6 / SwiftUI / macOS 26 menu bar app
**Mode**: standard | **Focus**: all

## Audit Coverage

| Tier | Auditors Dispatched | Description |
|------|---------------------|-------------|
| T1 — Universal | code-quality, security, test-coverage, docs-oss, performance, git-historian | Cross-cutting concerns |
| T2 — Language | swift-auditor | Swift language idioms, concurrency, memory |
| T3 — Framework | macos-auditor, i18n-auditor, ci-cd-auditor, ux-auditor, a11y-auditor | Framework/tooling specifics |

**Auditors skipped** (not detected): Dart/Flutter, JS/TS, Python, Rust, Go, Kotlin, Java, iOS/Android/watchOS/React Native, backend frameworks, BaaS, GraphQL, Docker, migrations, monorepo, API, Tailwind, e2e-web-tester.

## Summary
- Total findings: 78
- Critical: 8 | High: 22 | Medium: 28 | Low: 20
- By tier: T1: 33 | T2: 21 | T3: 24
- Quick wins available: 46 items (< 30 min each)
- **Top 3 priorities**:
  1. Uninstall deletes entire shared `~/Library/Caches/models/` root (destroys other MLX apps' data)
  2. Plaintext logging of every transcription + LLM output to world-readable file + missing accessibility labels on the menu bar entry button (blocks VoiceOver users entirely)
  3. 21 localization keys missing from both .strings files — pl users see English errors, en users see Polish labels

---

## Critical Findings

### [x] [C1] Uninstall destroys entire shared MLX cache root `[T1]`
- **File**: `MenuBar/FooterSection.swift:71`
- **Auditor**: security-auditor, code-quality-auditor, ux-auditor, docs-oss-auditor
- **Issue**: `performUninstall()` runs `removeItem(at: home.appendingPathComponent("Library/Caches/models"))` — the shared MLX cache used by ALL MLX-based apps on the machine (LM Studio, mlx-lm CLI, etc.). The confirmation dialog says "delete all downloaded models" but silently destroys other apps' multi-GB model caches. `DownloadedLLMModelStore.mlxCacheDir` correctly targets the `mlx-community/` subdirectory — the two paths are inconsistent.
- **Recommendation**: Change to `home.appendingPathComponent("Library/Caches/models/mlx-community")` to match `mlxCacheDir`. Update alert message accordingly.
- **Effort**: Quick Win

### [x] [C2] Plaintext transcription + LLM content written to world-readable unbounded log `[T1]`
- **File**: `DictationPipeline.swift:270,292,298,314`, `DictumLogger.swift:21`
- **Auditor**: security-auditor, performance-auditor, code-quality-auditor
- **Issue**: `dlog()` writes raw transcription text, LLM prompts, LLM output, final pasted text, and selected-text context (up to 100 chars) to `~/Library/Logs/Dictum/dictum.log`. File created with default 0644 (world-readable), never rotated, grows indefinitely. Any process running as the same user — or any app with Full Disk Access — can read a permanent transcript of everything the user dictates (passwords, messages, medical/financial info).
- **Recommendation**: (a) Strip content from logs — log metadata only (e.g., `transcription complete, \(rawText.count) chars`). (b) Create the log with `0600` POSIX permissions. (c) Add rotation at 1 MB. (d) Consider switching to `os.Logger` entirely.
- **Effort**: Moderate

### [x] [C3] WhisperKit `verbose: true` + `logLevel: .debug` hardcoded in release builds `[T1]`
- **File**: `Transcription/TranscriptionEngine.swift:32-33,47-48`
- **Auditor**: security-auditor
- **Issue**: Both `loadModel` paths hardcode `verbose: true` and `logLevel: .debug` in `WhisperKitConfig`. Debug output — including audio processing internals — is emitted to unified logging (`os_log`) and visible to anyone running `log stream` on the machine.
- **Recommendation**: Remove both flags or gate behind `#if DEBUG`.
- **Effort**: Quick Win

### [x] [C4] Path traversal in `DownloadedLLMModelStore.deleteModel` `[T1]`
- **File**: `ModelBrowser/DownloadedLLMModelStore.swift:62-64`
- **Auditor**: security-auditor
- **Issue**: `deleteModel(_ modelId:)` strips `mlx-community/` prefix and calls `mlxCacheDir.appendingPathComponent(folderName)` with no canonicalization. A model ID like `mlx-community/../../../Library/Application Support/SomeApp` would escape the cache directory. Values originate from HuggingFace API responses; a compromised/MITM'd response could cause arbitrary deletion under `$HOME` (non-sandboxed app).
- **Recommendation**: After resolving, verify `resolved.path.hasPrefix(mlxCacheDir.standardizedFileURL.path + "/")` before `removeItem(at:)`.
- **Effort**: Quick Win


### [ ] [C6] 21 localization keys missing from both .strings files — UI renders in wrong language `[T3]`
- **File**: `MenuBar/STTLanguageSection.swift:9,14,32,46,58`; `MenuBar/DownloadedModelDeletionAlerts.swift:10-74`; `Settings/AppSettings.swift:27`; `Transcription/TranscriptionEngine.swift:11,13`; `TextProcessing/LLMProcessor.swift:13,15`; `MenuBar/InstalledAppPickerSheet.swift:44,57,58`; `MenuBar/FooterSection.swift:29,36`; `MenuBar/SetupFooterView.swift:16`
- **Auditor**: i18n-auditor, macos-auditor, ux-auditor
- **Issue**: ~21 keys used via `String(localized:defaultValue:)` are absent from both `en.lproj` and `pl.lproj`. Because `defaultValue` is whichever language the developer wrote (sometimes Polish, sometimes English), en users see Polish for STT language section, delete alerts, and "Wersja:" footer; pl users see English error messages for STT/LLM failures. Also, `header.processingLLM` `defaultValue` in code ("Cleaning text…") contradicts .strings value ("Processing text…").
- **Recommendation**: Write missing keys to both `.strings` files (use `python3` to preserve UTF-16 BOM — do NOT use the Write tool on .strings). Align all `defaultValue` args to English. Extract `"Wersja: %@"` from the two hardcoded Swift sites. Fix `header.processingLLM` mismatch.
- **Effort**: Moderate


### [x] [C8] Whisper STT model download failure is silent — user stuck at onboarding dead end `[T3]`
- **File**: `Transcription/WhisperModelStore.swift:127-128`
- **Auditor**: ux-auditor
- **Issue**: The `catch` block in `downloadAndActivate` only calls `dlog()`. The row reverts to the undownloaded state with the download-arrow icon, no error is `@Published`. In SetupView, STT download is the only required step — a user with network/disk issues gets zero feedback and no path forward.
- **Recommendation**: Add `@Published var downloadError: String?` to `WhisperModelStore` (parallel to `LLMModelDownloadController`). Set it in the catch; render in `SetupSpeechRecognitionModelStep` the same way `LLMModelDownloadErrorView` does.
- **Effort**: Quick Win

---

## High Priority Findings

### [x] [H1] Data race on `nonisolated(unsafe)` cached hotkey config `[T2]`
- **File**: `HotkeyAndPaste/GlobalHotkeyMonitor.swift:20-22,53-55,119-120`
- **Auditor**: swift-auditor
- **Issue**: `cachedIsModifierOnly`, `cachedKeyCode`, `cachedModifiers` are written on `@MainActor` and read from the CGEvent tap thread with no synchronization. Benign on Apple Silicon today, formally UB under Swift concurrency model, will trip Swift 6 strict concurrency.
- **Recommendation**: Wrap in `OSAllocatedUnfairLock<CachedHotkeyConfig>` or use `Synchronization.Atomic` (available on macOS 26). Snapshot as a single struct.
- **Effort**: Moderate

### [x] [H2] `AudioRecorder.appendSamples` dispatches strong `self` to main queue `[T2]`
- **File**: `Audio/AudioRecorder.swift:126-129`
- **Auditor**: swift-auditor
- **Issue**: The outer `installTap` closure captures `[weak self]`, but the inner `DispatchQueue.main.async` inside `appendSamples` captures `self` strongly, keeping `AudioRecorder` alive across teardown windows.
- **Recommendation**: Add `[weak self]` to the inner async block.
- **Effort**: Quick Win

### [x] [H3] Synthetic Cmd+C posted to `.cghidEventTap` re-enters own event tap `[T3]`
- **File**: `HotkeyAndPaste/SelectedTextCapture.swift:42-43`
- **Auditor**: macos-auditor
- **Issue**: Posting to `.cghidEventTap` re-injects at HID level, passing through Dictum's own `GlobalHotkeyMonitor` tap. If the user configures `C` + `Command` as their hotkey, context capture triggers a second dictation. `ClipboardPasteController` correctly uses `.cgAnnotatedSessionEventTap`.
- **Recommendation**: Change both `keyDown.post` / `keyUp.post` calls to `.cgAnnotatedSessionEventTap`.
- **Effort**: Quick Win

### [x] [H4] `appendSamples` allocates `[Float]` + does `map.reduce` in hot audio path `[T3]`
- **File**: `Audio/AudioRecorder.swift:83,120`
- **Auditor**: performance-auditor
- **Issue**: ~64 callbacks/sec allocate new `[Float]` via `Array(UnsafeBufferPointer(...))`, then `samples.map { $0 * $0 }.reduce(0, +)` builds another intermediate array before summing. `audioBuffer` has no `reserveCapacity` — a 60s recording causes ~20 reallocations doubling storage.
- **Recommendation**: `reserveCapacity(16000 * estimatedDurationSeconds)` in `startRecording`; append directly from `UnsafeBufferPointer` without intermediate Array; compute RMS with `Accelerate.vDSP_svesq` (zero-allocation sum-of-squares).
- **Effort**: Quick Win

### [x] [H5] App icons fetched synchronously from disk on every SwiftUI re-render `[T3]`
- **File**: `MenuBar/AppMetadata.swift:5-8` called from `LLMPromptSections.swift:155`, `STTLanguageSection.swift:89`
- **Auditor**: performance-auditor
- **Issue**: `applicationIcon(forBundleId:)` calls `NSWorkspace.urlForApplication` + `NSWorkspace.icon(forFile:)` synchronously from `body`. SwiftUI re-evaluates rows on every `AppSettings.objectWillChange`, which fires on every keystroke in any prompt text editor due to `saveAppPrompts` → dozens of disk stats per second on main thread.
- **Recommendation**: Cache in `AppSettings` as `[String: NSImage]`, or load into `@State` inside the row via `task(id: bundleId)`.
- **Effort**: Moderate

### [x] [H6] `WhisperModelStore.totalSizeOnDisk()` walks filesystem from inside computed property `[T3]`
- **File**: `Transcription/WhisperModelStore.swift:172`, used at `MenuBar/DownloadedModelsSection.swift:20`
- **Auditor**: performance-auditor
- **Issue**: Called from a SwiftUI computed property during render. Walks `~/.cache/huggingface/hub/` (thousands of files) on every view update, including 2Hz updates during download progress.
- **Recommendation**: Mirror `DownloadedLLMModelStore` — store `@Published var totalSizeOnDisk: Int64`, update only after download/delete.
- **Effort**: Moderate


### [x] [H9] No SPM cache + no job timeout in release.yml `[T3]`
- **File**: `.github/workflows/release.yml:13,37-38`
- **Auditor**: ci-cd-auditor, docs-oss-auditor
- **Issue**: Every release re-downloads WhisperKit + mlx-swift-lm + Sparkle (~3-5 min). Job has no `timeout-minutes` — a hang runs for GitHub's default 360-minute cap.
- **Recommendation**: Add `actions/cache` keyed on `hashFiles('**/Package.resolved')` caching `~/Library/Developer/Xcode/DerivedData/**/SourcePackages/{checkouts,repositories}`. Add `timeout-minutes: 30`.
- **Effort**: Quick Win



### [x] [H11] `SetupLLMProcessingStep.startDownload` busy-waits on `pipeline.llmIsDownloading` `[T2]`
- **File**: `MenuBar/SetupLLMProcessingStep.swift:61-74`
- **Auditor**: code-quality-auditor, swift-auditor
- **Issue**: `while pipeline.llmIsDownloading { try await Task.sleep(for: .milliseconds(200)) }` — polling loop on the main actor, no cancellation check, unstructured `Task` never cancelled on view disappear.
- **Recommendation**: Use `.onChange(of: pipeline.llmIsDownloading)` or a `Combine` sink on `llmModelDownloadController.objectWillChange`. Use `.task` modifier so SwiftUI owns the lifecycle.
- **Effort**: Moderate

### [x] [H12] `InstalledAppPickerSheet` mutates `NSImage` from `Task.detached` (off-main) `[T2]`
- **File**: `MenuBar/InstalledAppPickerSheet.swift:115`
- **Auditor**: swift-auditor
- **Issue**: `icon.size = NSSize(...)` inside a `Task.detached` closure. `NSImage` is not documented as thread-safe for mutation; this is a data race.
- **Recommendation**: Build the `InstalledAppInfo` struct in the detached task and hop to `@MainActor` for size assignment. Or remove the `.size` mutation entirely (it doesn't actually downsample the bitmap — see also L-finding on icon memory).
- **Recommendation**: Move mutation to `@MainActor` or produce a properly downsampled bitmap via `lockFocus`.
- **Effort**: Moderate

### [x] [H13] `TranscriptionEngine.loadWhisperKit` has racy `loadingTask` lifecycle `[T2]`
- **File**: `Transcription/TranscriptionEngine.swift:57-68`
- **Auditor**: swift-auditor
- **Issue**: Inner `Task` sets `loadingTask = nil` in its `defer`, racing with the outer assignment. The pattern is hard to reason about and the guard only holds by coincidence.
- **Recommendation**: Remove the inner `Task` wrapper — actors already serialize method calls. Assign and await directly in the outer method.
- **Effort**: Moderate

### [x] [H14] HuggingFace search failures silent — looks identical to "no results" `[T3]`
- **File**: `ModelBrowser/HuggingFaceModelSearch.swift:34,40-43`
- **Auditor**: ux-auditor, security-auditor
- **Issue**: `URLSession.shared.data(from:)` with no timeout + `catch` that only calls `print()`. Network errors → empty results → UI looks like "model not found". HTTP status never validated.
- **Recommendation**: Dedicated `URLSession` with `timeoutIntervalForRequest: 10`, validate status code, `@Published var searchError: String?`, render under the search field as `.caption .foregroundStyle(.red)`.
- **Effort**: Moderate

### [x] [H15] `SetupLLMProcessingStep` shows no error feedback on LLM download failure `[T3]`
- **File**: `MenuBar/SetupLLMProcessingStep.swift`
- **Auditor**: ux-auditor
- **Issue**: `pipeline.llmDownloadError` is only rendered in `LLMModelSection` (post-setup). During setup, the row just resets silently.
- **Recommendation**: Render `LLMModelDownloadErrorView` under the model list in `SetupLLMProcessingStep` too.
- **Effort**: Quick Win


### [x] [H17] Audit finding: STT/LLM models deletable while actively loaded `[T1]`
- **File**: `Transcription/WhisperModelStore.swift:152`
- **Auditor**: code-quality-auditor
- **Issue**: `WhisperModelStore.deleteModel` does not unload the active `TranscriptionEngine` before removing files. A concurrent recording will try to use the deleted model folder.
- **Recommendation**: Before deleting the active model, `await TranscriptionEngine.shared.unloadModel()`. Mirror the `LLMProcessor.unloadModel()` pattern in `DownloadedModelsSection:63`.
- **Recommendation**: Await unload first.
- **Effort**: Quick Win

### [ ] [H18] `DictumLogger` log file unbounded — no rotation `[T1]`
- **File**: `DictumLogger.swift:27`
- **Auditor**: code-quality-auditor, performance-auditor
- **Issue**: ~60 `dlog()` callsites per dictation, no size cap, no rotation. Daily users accumulate permanent ever-growing log.
- **Recommendation**: Switch to `os.Logger` (system handles rotation, integrates with Console.app) or add size check on open rotating to `.log.bak` at 1-10 MB. Also add `deinit { handle?.closeFile() }`.
- **Effort**: Moderate

### [x] [H19] Error state in `PopoverStatusHeader` rendered yellow — same as transcribing `[T3]`
- **File**: `MenuBar/PopoverStatusHeader.swift:65`
- **Auditor**: ux-auditor, a11y-auditor
- **Issue**: `AppState.error` → `.yellow` (same as transcribing). Every other error surface uses `.red`. Confuses state, and red/green colorblind users can't distinguish error from other states.
- **Recommendation**: Change `case .error: return .red` in `stateColor`. Add a `⚠` glyph prefix to `stateDescription` for the error case.
- **Effort**: Quick Win

### [x] [H20] Preloaded STT/LLM via fire-and-forget `Task` with swallowed errors `[T2]`
- **File**: `DictationPipeline.swift:56-76`
- **Auditor**: swift-auditor
- **Issue**: `preloadSTTModel`'s `Task { ... }` is discarded; `try?` swallows errors silently. Races with `warmupTask` — both can concurrently call `loadModel`.
- **Recommendation**: Store task in property; add `do/catch` with `dlog`; coordinate with `warmupTask`.
- **Effort**: Moderate

### [x] [H21] `SystemPermissionStore` polling timer never stopped on popover close `[T3]`
- **File**: `Settings/SystemPermissionStore.swift:58-75`, `MenuBar/PopoverView.swift:26-28`
- **Auditor**: macos-auditor
- **Issue**: `startPolling()` called in `onAppear` runs at 1 Hz until `allGranted == true`. If user dismisses popover without granting, timer runs forever, waking the process at 1 Hz for days.
- **Recommendation**: Add `stopPolling()` in `.onDisappear`.
- **Effort**: Quick Win

---

## Medium Priority Findings

### [x] [M1] `directorySize` duplicated verbatim in two model stores `[T1]`
- **File**: `ModelBrowser/DownloadedLLMModelStore.swift:76`, `Transcription/WhisperModelStore.swift:195`
- **Auditor**: code-quality-auditor
- **Recommendation**: Extract to `FileManager` extension or `FileSystemUtils.directorySize(_:)`. Also add `includingPropertiesForKeys: [.fileSizeKey]` to enumerator (batched `stat`).
- **Effort**: Quick Win

### [x] [M2] `"mlx-community/"` prefix hardcoded in 6 sites `[T1]`
- **File**: `DownloadedLLMModelStore.swift:26,49,62`, `HuggingFaceModelInfo.swift:15`, `LLMModelDownloadStatusView.swift:10`, `DownloadedLLMModelsList.swift:23`
- **Auditor**: code-quality-auditor
- **Recommendation**: Single constant `ModelIDConstants.mlxCommunityPrefix`.
- **Effort**: Quick Win

### [x] [M3] `pendingSelectedContext` is public `var` on singleton with external writers `[T1]`
- **File**: `DictationPipeline.swift:25`
- **Auditor**: code-quality-auditor
- **Recommendation**: `private(set)` + method `setPendingContext(_:)`.
- **Effort**: Quick Win

### [x] [M4] `DictationPipeline.handleProcessingError` unstored auto-clear Task `[T1]`
- **File**: `DictationPipeline.swift:341-346`
- **Auditor**: code-quality-auditor, swift-auditor
- **Recommendation**: Store as `private var errorResetTask: Task<Void, Never>?`; `.cancel()` in `startRecording`.
- **Effort**: Quick Win

### [x] [M5] `GlobalHotkeyMonitor` duplicates `accessibilityGranted`/`requestAccessibility` from `SystemPermissionStore` `[T1]`
- **File**: `HotkeyAndPaste/GlobalHotkeyMonitor.swift:29`
- **Auditor**: code-quality-auditor
- **Recommendation**: Remove duplicates; call `SystemPermissionStore.shared` or accept a param.
- **Effort**: Moderate

### [x] [M6] `LLMModelDownloadController` doesn't clear prior error on new download `[T1]`
- **File**: `DictationPipeline.swift:32` / `LLMModelDownloadController`
- **Auditor**: code-quality-auditor
- **Recommendation**: `downloadError = nil` at top of `downloadModel()`.
- **Effort**: Quick Win



### [x] [M8] `InstalledAppPickerSheet.loadInstalledApps` duplicate scan loops `[T1]`
- **File**: `MenuBar/InstalledAppPickerSheet.swift:94-131`
- **Auditor**: code-quality-auditor
- **Recommendation**: Extract `scanApps(in:seen:)` helper.
- **Effort**: Quick Win

### [ ] [M9] `cleanAppName` computed in three places `[T1]`
- **File**: `LLMPromptSections.swift:133`, `STTLanguageSection.swift:76`, `InstalledAppPickerSheet.swift:113`
- **Auditor**: code-quality-auditor
- **Recommendation**: Clean once at storage time in `InstalledAppPickerSheet`.
- **Effort**: Quick Win

### [x] [M10] `NSPanel` + `NSHostingView` recreated on every dictation start `[T3]`
- **File**: `FloatingIndicator/FloatingIndicatorPanelController.swift:37-79`
- **Auditor**: macos-auditor, performance-auditor
- **Recommendation**: Lazy-create once, `orderFrontRegardless` / `orderOut` for show/hide.
- **Effort**: Moderate

### [ ] [M11] `@ObservedObject` on singleton inside `PopoverView` and `LLMModelSection` `[T3]`
- **File**: `MenuBar/PopoverView.swift:8`, `MenuBar/LLMModelSection.swift:10`
- **Auditor**: macos-auditor
- **Recommendation**: Inject `SystemPermissionStore.shared` and `HuggingFaceModelSearch.shared` via `.environmentObject` from `MenuBarController.setupPopover`.
- **Effort**: Quick Win

### [x] [M12] `ClipboardPasteController` uses nested `asyncAfter` with uncancellable timers `[T3]`
- **File**: `HotkeyAndPaste/ClipboardPasteController.swift:32-45`
- **Auditor**: macos-auditor, swift-auditor
- **Recommendation**: Rewrite as cancellable `Task` chain; back-to-back dictations currently overwrite each other's clipboard restoration.
- **Effort**: Moderate

### [x] [M13] Escape key unconditionally intercepts even when not recording `[T3]`
- **File**: `HotkeyAndPaste/GlobalHotkeyMonitor.swift:145-158`
- **Auditor**: macos-auditor
- **Recommendation**: Guard on `DictationPipeline.shared.isRecording` before dispatching cancel.
- **Effort**: Quick Win

### [x] [M14] `SelectedTextReader` double AX IPC for role lookup per ancestor element `[T3]`
- **File**: `FloatingIndicator/TextInputAnchorResolver.swift:69-78,135`
- **Auditor**: performance-auditor
- **Recommendation**: Pass already-fetched role string into `caretRect(for:role:)`.
- **Effort**: Quick Win

### [x] [M15] `unsafeBitCast` CF bridging duplicated in two files `[T2]`
- **File**: `SelectedTextCapture.swift:107,114`, `TextInputAnchorResolver.swift:230,237`
- **Auditor**: swift-auditor
- **Recommendation**: Extract `AXBridge` namespace with `axUIElement(from:)` / `axValue(from:)` helpers.
- **Effort**: Quick Win

### [x] [M16] `AppSettings.saveAppPrompts` JSON-encodes on every keystroke `[T2]`
- **File**: `Settings/AppSettings.swift:195,239`
- **Auditor**: performance-auditor, swift-auditor
- **Recommendation**: Cache encoder/decoder as `private let`; debounce saves (500ms). Also replace `try?` with `do/catch` + `dlog`.
- **Effort**: Moderate

### [x] [M17] `FloatingIndicatorView.sampleLevel` uses `removeFirst()` on 16-element buffer at 60fps `[T3]`
- **File**: `FloatingIndicator/FloatingIndicatorView.swift:91`
- **Auditor**: performance-auditor
- **Recommendation**: Ring buffer with head index.
- **Effort**: Quick Win

### [x] [M18] `DictumLogger.log` formats `Date()` via `description` per call `[T2]`
- **File**: `DictumLogger.swift:28`
- **Auditor**: performance-auditor
- **Recommendation**: Static `ISO8601DateFormatter` or switch to `os.Logger`.
- **Effort**: Quick Win

### [x] [M19] `@AppStorage` + manual UserDefaults mix in `AppSettings` `[T2]`
- **File**: `Settings/AppSettings.swift:124-148`
- **Auditor**: code-quality-auditor, swift-auditor
- **Recommendation**: Add a comment explaining `@AppStorage` doesn't support `Codable`.
- **Effort**: Quick Win

### [ ] [M20] `GlobalHotkeyMonitor.captureSelectedText` three-hop dispatch chain `[T2]`
- **File**: `HotkeyAndPaste/GlobalHotkeyMonitor.swift:234-243`
- **Auditor**: swift-auditor
- **Recommendation**: Convert to `async` function; single `Task.detached` + `await MainActor.run`.
- **Effort**: Moderate

### [ ] [M21] 9 dead i18n keys in both .strings files `[T3]`
- **File**: `Resources/en.lproj/Localizable.strings`, `Resources/pl.lproj/Localizable.strings`
- **Auditor**: i18n-auditor
- **Issue**: `section.prompt`, `section.llm.prompt`, `section.llm.nomodel`, `section.llm.active`, `section.downloaded.llm`, `section.downloaded.whisper`, `section.prompt.placeholder.hint`, `section.prompt.reset`, `footer.quit` — never referenced in code.
- **Recommendation**: Remove from both files via `python3` (preserves UTF-16).
- **Effort**: Quick Win

### [ ] [M22] No `.stringsdict` — `%lld` format doesn't handle Polish plural forms `[T3]`
- **File**: `Resources/en.lproj/Localizable.strings:34` (`section.stt.more`)
- **Auditor**: i18n-auditor
- **Recommendation**: Create `Localizable.stringsdict` in both locales with ICU plural rules. Polish needs one/few/many/other.
- **Effort**: Moderate



### [ ] [M24] Example prompt button injects hardcoded Polish content `[T3]`
- **File**: `MenuBar/LLMPromptSections.swift:57-59`
- **Auditor**: i18n-auditor
- **Recommendation**: Move content to `.strings` under `"prompt.example.content"`.
- **Effort**: Moderate



### [ ] [M26] Sparkle SHA256 in release.yml is 63 chars (should be 64) `[T3]`
- **File**: `.github/workflows/release.yml:65`
- **Auditor**: macos-auditor
- **Issue**: `09fed60cca507d2dc542c86c22e525598af5483954a5c66366ce039647ec88e9` — possibly truncated or missing leading zero.
- **Recommendation**: Re-generate: `curl -sL "https://github.com/sparkle-project/Sparkle/releases/download/2.7.0/Sparkle-2.7.0.tar.xz" | shasum -a 256`.
- **Effort**: Quick Win

### [ ] [M27] `Dictum.entitlements` is empty `<dict/>` `[T3]`
- **File**: `Resources/Dictum.entitlements:1-5`
- **Auditor**: security-auditor
- **Recommendation**: Declare `com.apple.security.device.microphone` explicitly. Research AX entitlement for CGEvent tap.
- **Effort**: Moderate

### [x] [M28] SetupView "Skip" button is a no-op — no visual confirmation `[T3]`
- **File**: `MenuBar/SetupLLMProcessingStep.swift:42-44`
- **Auditor**: ux-auditor
- **Recommendation**: `@State var isSkipped`; mark step as done/skipped; update `isUnlocked` gate in `SetupView.swift:24`.
- **Effort**: Quick Win

---

## Low Priority Findings

### [x] [L1] Magic keycodes (53, 54, 0x08, 0x09, 0x37) scattered `[T1]`
- **File**: `GlobalHotkeyMonitor.swift:150`, `HotkeyRecorder.swift:20`, `SelectedTextCapture.swift`, `ClipboardPasteController.swift`
- **Recommendation**: `KeyCodes` enum.
- **Effort**: Quick Win

### [x] [L2] `print()` instead of `dlog()` in error paths `[T1]`
- **File**: `GlobalHotkeyMonitor.swift:100`, `HuggingFaceModelSearch.swift:41`
- **Recommendation**: Replace with `dlog`.
- **Effort**: Quick Win

### [x] [L3] `AppState.done` case never assigned — dead code `[T1]`
- **File**: `Settings/AppRuntimeState.swift:9`, `DictationPipeline.swift:324`, `MenuBarController.swift:73-79`
- **Recommendation**: Either assign in `finishProcessing()` or remove enum case + switch arms.
- **Effort**: Quick Win

### [ ] [L4] `SetupLLMRow` / `SetupModelRow` / `DownloadedLLMModelsList` / `DownloadedWhisperModelsList` near-identical `[T1]`
- **File**: `MenuBar/SetupStepViews.swift:35,127`, `DownloadedLLMModelsList.swift`, `DownloadedWhisperModelsList.swift`
- **Recommendation**: Protocol + generic `ModelDownloadRow<M>` view.
- **Effort**: Moderate

### [x] [L5] Missing `Sendable` on `STTLanguage`, `RecordingMode`, `AppState` `[T2]`
- **File**: `Settings/AppSettings.swift:6,80`, `Settings/AppRuntimeState.swift:3`
- **Recommendation**: Add `Sendable`.
- **Effort**: Quick Win

### [x] [L6] `GhostTextView` (`NSTextView` subclass) not `@MainActor` `[T2]`
- **File**: `MenuBar/PromptTextEditor.swift:4`
- **Recommendation**: Annotate `@MainActor`.
- **Effort**: Quick Win

### [x] [L7] `AVAudioFormat(...)!` force-unwrap without comment `[T2]`
- **File**: `Audio/AudioRecorder.swift:54`
- **Recommendation**: `guard let else fatalError("internal: ...")`.
- **Effort**: Quick Win

### [x] [L8] `KeyCodeMapping.keyName` rebuilds dictionary every call `[T2]`
- **File**: `MenuBar/HotkeyRecorder.swift:109`
- **Recommendation**: Hoist to `private static let`.
- **Effort**: Quick Win

### [x] [L9] `MenuBarController.shared` assigned inside init, not atomically `[T3]`
- **File**: `MenuBar/MenuBarController.swift:21`
- **Recommendation**: Set `shared = self` as first line of `init`.
- **Effort**: Quick Win

### [ ] [L10] `LaunchAtLoginPreferenceToggle` initial `@State` stale between openings `[T3]`
- **File**: `MenuBar/LaunchAtLoginPreferenceToggle.swift:6`
- **Recommendation**: Existing `onAppear` sync is adequate; polish only.
- **Effort**: Quick Win

### [x] [L11] `NSPopover.contentSize` hardcoded to 640pt height `[T3]`
- **File**: `MenuBar/MenuBarController.swift:38`
- **Recommendation**: Reduce to 560pt or use `preferredContentSize` from `sizeThatFits`.
- **Effort**: Quick Win

### [x] [L12] No `applicationWillTerminate` cleanup of hotkey tap/audio `[T3]`
- **File**: `DictumApp.swift`
- **Recommendation**: `AppDelegate.applicationWillTerminate(_:)` → `DictationPipeline.cancelOperation()` + `GlobalHotkeyMonitor.shared.stop()`.
- **Effort**: Quick Win

### [ ] [L13] `openAccessibilitySettings` uses legacy URL scheme `[T3]`
- **File**: `Settings/SystemPermissionStore.swift:43,50`
- **Recommendation**: Test `com.apple.SystemPreferences.PrivacySettings?Privacy_Accessibility` under macOS 26 with legacy fallback.
- **Effort**: Quick Win

### [x] [L14] Per-app trash button explanation missing on active STT model `[T3]`
- **File**: `MenuBar/DownloadedWhisperModelsList.swift:38-39`
- **Recommendation**: `.help("Switch to another model first to delete this one")`.
- **Effort**: Quick Win

### [x] [L15] HF search min-chars hint missing `[T3]`
- **File**: `MenuBar/LLMModelSection.swift:45-53`
- **Recommendation**: Show "Type at least 2 characters" when query length == 1.
- **Effort**: Quick Win

### [x] [L16] LLM model deletion error swallowed with `try?` `[T3]`
- **File**: `MenuBar/DownloadedModelDeletionAlerts.swift:58-65`
- **Recommendation**: Surface failure inline.
- **Effort**: Quick Win

### [x] [L17] `FloatingIndicatorView.dotTimer` `DispatchQueue.main.async` inside main-thread timer `[T3]`
- **File**: `FloatingIndicator/FloatingIndicatorView.swift:72-77`
- **Recommendation**: Remove redundant dispatch.
- **Effort**: Quick Win

### [x] [L18] Decorative SF Symbols not hidden from a11y tree + reduce-motion not respected `[T3]`
- **File**: `DownloadedModelsStorageSummary.swift:9`, `HuggingFaceSearchField.swift:12`, `PermissionsNeededView.swift:13`, `SetupHeaderView.swift:7`, `PopoverStatusHeader.swift:12`, `FloatingIndicatorView.swift:16`
- **Recommendation**: `.accessibilityHidden(true)` on decorative glyphs; read `@Environment(\.accessibilityReduceMotion)` and substitute static indicator in pill.
- **Effort**: Quick Win

### [ ] [L19] Missing OSS hygiene files: CONTRIBUTING.md, CODE_OF_CONDUCT.md, issue templates `[T1]`
- **File**: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `.github/ISSUE_TEMPLATE/` (missing)
- **Auditor**: docs-oss-auditor
- **Recommendation**: Add short CONTRIBUTING.md with Xcode 26 + XcodeGen + signing + dev cycle, bug_report.md template with OS version + model IDs + log snippet, Contributor Covenant 2.1.
- **Effort**: Moderate

### [x] [L20] Missing `.xcuserstate` in `.gitignore` + no `.gitattributes` `[T1]`
- **File**: `.gitignore`, `.gitattributes` (missing)
- **Auditor**: git-historian
- **Recommendation**: Add `*.xcuserstate` to `.gitignore`; add minimal `.gitattributes` with `* text=auto` + `*.png binary`.
- **Effort**: Quick Win

---

## Test Coverage Gap Analysis

Per CLAUDE.md policy, tests are NOT wanted — manual QA only. Test-coverage findings are intentionally kept Low; only pure-logic helpers are flagged for optional extraction if the policy ever changes:

| Directory | Files | Test Coverage | Priority | Notes |
|-----------|-------|---------------|----------|-------|
| `TextProcessing/` | `LLMProcessor.swift` | None | Low* | 4-branch `cleanText` prompt routing; `<think>` stripping — both pure logic, easy to extract |
| `Settings/` | `AppSettings.swift` | None | Low* | `resolvePrompt` / `resolveSTTLanguage` / `STTLanguage.systemDefault` — pure |
| `HotkeyAndPaste/` | `GlobalHotkeyMonitor.swift` | None | Low* | 3 `nonisolated static` keycode helpers; Caps Lock (57) inconsistency between `isModifierKeyCode` and `modifierFlag` |
| Audio / Transcription / FloatingIndicator / MenuBar | ~40 files | None | N/A | Hardware- or UI-dependent; not unit-testable |

`*` Policy-dependent priority.

---

## Suggested Improvements

| Area | Description | Impact |
|------|-------------|--------|
| **Security** | Fix C1–C4 + C5 (uninstall scope, transcript logging, WhisperKit debug flags, path traversal, action SHA-pinning) | Prevents data loss, information leaks, supply-chain compromise of signed updates |
| **i18n** | Ship all 21 missing keys + remove 9 dead keys + add `.stringsdict` | Brings actual locale coverage to 100% — currently 38% of used keys are missing |
| **A11y** | Systemic `.accessibilityLabel` pass on status item button, icon buttons, toggles, pickers | Unblocks VoiceOver users who today cannot operate the app at all |
| **Performance** | vDSP sum-of-squares, `reserveCapacity` on audioBuffer, cached app icons, cached Whisper disk size | Eliminates heap churn in audio callback + synchronous disk I/O in SwiftUI body |
| **Concurrency** | Lock `nonisolated(unsafe)` hotkey cache, off-main `NSImage` mutation, structured task lifecycle for busy-wait polling loops | Removes latent races + enables Swift 6 strict concurrency mode |
| **CI/CD** | Add PR validation workflow, SPM cache, job timeout, split-permission release job, SHA pinning + Dependabot | Prevents broken builds on main; hardens the release supply chain |
| **UX** | Surface STT/HF-search/LLM-download errors, first-run CoreML hint, accurate uninstall scope dialog, unique error color | Removes silent dead ends in onboarding |
| **Docs** | README Known Limitations, CONTRIBUTING.md, stable `appcast.xml` on Pages | OSS readiness + stable auto-update channel |
