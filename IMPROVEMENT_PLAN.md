# Project Audit Report

**Audited**: Dictum | **Date**: 2026-03-29 | **Type**: Swift/SwiftUI macOS app (XcodeGen, SPM)
**Mode**: deep | **Focus**: quality

## Audit Coverage

| Tier | Auditors Dispatched | Description |
|------|---------------------|-------------|
| T1 - Universal | code-quality-auditor | Code smells, duplication, naming, SOLID, complexity |
| T2 - Language | swift-objc-auditor | Swift idioms, actors, Sendable, memory management, error handling |
| T3 - Framework | ios-auditor, ux-auditor | macOS/SwiftUI patterns, NSPanel, CGEvent tap, UX anti-patterns |

**Auditors skipped** (focus=quality): security-auditor, test-coverage-auditor, docs-oss-auditor, performance-auditor, git-historian, ci-cd-auditor, i18n-auditor, a11y-auditor

## Summary
- Total findings: **42**
- Critical: 2 | High: 12 | Medium: 18 | Low: 10
- By tier: T1: 16 | T2: 14 | T3: 12
- Quick wins available: **22 items** (< 30 min each)
- Top 3 priorities:
  1. Model deletion without confirmation — data loss risk
  2. `AppSettings` missing `@MainActor` — data race from event tap callback
  3. Force casts in AX API — crash surface during active recording

## Critical Findings

### [x] [C1] Trash icon deletes model with no confirmation `[T3]`
- **File**: `MenuBar/PopoverView.swift:2001–2007` (STT), `:2035–2045` (LLM)
- **Auditor**: ux-auditor
- **Issue**: Trash button fires `deleteModel()` immediately on tap with no confirmation. Deleting a 1.5 GB+ Whisper or 2.5 GB LLM model is irreversible and requires a long re-download. A fat-finger on the trash icon while scrolling loses several GB with no recovery.
- **Recommendation**: Wrap in `.confirmationDialog` or `.alert` — mirror the existing uninstall alert pattern in `FooterSection` (line 2124).
- **Effort**: Quick Win

### [x] [C2] LLM download error silently lost when popover closes `[T3]`
- **File**: `MenuBar/PopoverView.swift:1453–1457`
- **Auditor**: ux-auditor
- **Issue**: `downloadError` is `@State` on `LLMModelSection`. When the popover closes (`.transient` behavior), the SwiftUI view tree is recreated and the error string is lost. User who closes the popover to check internet has no indication of what happened when returning.
- **Recommendation**: Persist the error to a `@Published` property on a longer-lived object (e.g., `LLMProcessor` or a download manager).
- **Effort**: Moderate

## High Priority Findings

### [x] [H1] `AppSettings` accessed from `nonisolated` event tap callback — data race `[T2]`
- **File**: `HotkeyAndPaste/GlobalHotkeyManager.swift:99–100`
- **Auditor**: swift-objc-auditor, code-quality-auditor
- **Issue**: `handleEvent` is `nonisolated` and called from the CGEvent tap run loop (not main thread). It reads `AppSettings.shared.hotkeyIsModifierOnly` and `.hotkeyKeyCode` — `@AppStorage` properties on a non-`@MainActor` class. This is a data race. Also reads `.hotkeyModifiers` at line 149.
- **Recommendation**: Annotate `AppSettings` with `@MainActor`. Cache hotkey values into local properties on `GlobalHotkeyManager` at start time; read cached values from the `nonisolated` handler.
- **Effort**: Moderate

### [x] [H2] Force-unwrap casts in AX API `caretRect` — crash surface `[T2]`
- **File**: `FloatingIndicator/FloatingIndicatorManager.swift:241,252,257,267`
- **Auditor**: swift-objc-auditor, ios-auditor
- **Issue**: `focusedElement as! AXUIElement` and `caretBounds as! AXValue` will crash if the AX API returns an unexpected type (e.g., sandboxed process, restricted element). Called during active dictation on `@MainActor`.
- **Recommendation**: Replace with `as? AXUIElement` / `as? AXValue` with `guard let` — the function already returns `CGRect?`.
- **Effort**: Quick Win

### [x] [H3] `dlog()` opens a new FileHandle on every call — ~60 callsites `[T1]`
- **File**: `DictationPipeline.swift:6–19`
- **Auditor**: code-quality-auditor, swift-objc-auditor, ios-auditor
- **Issue**: Each call opens `FileHandle`, seeks to end, writes, closes — three syscalls per log line. Also calls `createDirectory` on every invocation. Called from audio tap callback (~256ms intervals) and hot paths.
- **Recommendation**: Create a logger singleton with a persistent `FileHandle` opened once. Use `Data(line.utf8)` instead of `line.data(using: .utf8)!`. Consider `os.Logger` for structured logging.
- **Effort**: Moderate

### [x] [H4] Hotkey recorder leaves global hotkey permanently disabled on popover dismiss `[T3]`
- **File**: `MenuBar/PopoverView.swift:796–860`
- **Auditor**: ux-auditor, ios-auditor
- **Issue**: `startRecording()` calls `hotkeyManager.stop()`. If the popover is dismissed before a key is pressed, `stopRecording()` is never called (only `deinit` removes monitors, but doesn't call `setupHotkey()`). Dictum becomes non-functional until relaunched.
- **Recommendation**: Add `if isRecording { DictationPipeline.shared.setupHotkey() }` to `deinit`. Also add a 10-second auto-cancel timeout.
- **Effort**: Quick Win

### [x] [H5] `WhisperModelManager` timer not invalidated on throw — timer leak `[T2]`
- **File**: `Transcription/WhisperModelManager.swift:104–113`
- **Auditor**: swift-objc-auditor
- **Issue**: Repeating `Timer` created inside `downloadAndActivate`. If `loadModel(fromFolder:)` throws before line 113, the timer is never invalidated. It keeps firing on the run loop until task deallocation.
- **Recommendation**: Wrap in `defer { loadingTimer.invalidate() }` immediately after creation.
- **Effort**: Quick Win

### [x] [H6] `TranscriptionEngine.loadModel` silently discards concurrent load — race with transcribe `[T2]`
- **File**: `Transcription/TranscriptionEngine.swift:27,48`
- **Auditor**: swift-objc-auditor
- **Issue**: If `loadModel` is called while another load is in flight, the second call returns silently. Caller proceeds to `transcribe()` even though `isModelLoaded` may still be `false`. `defer { isLoading = false }` runs before `isModelLoaded = true`.
- **Recommendation**: Use a shared `loadingTask: Task<Void, Error>?` pattern where concurrent callers `await` the same in-flight task.
- **Effort**: Moderate

### [x] [H7] `MenuBarIcon.microphone(state:)` ignores its `state` parameter `[T1]`
- **File**: `MenuBar/MenuBarIcon.swift:92–100`
- **Auditor**: code-quality-auditor
- **Issue**: Function accepts `state: AppState` but the body never references it. All callers get the identical icon regardless of state. The parameter contract is broken.
- **Recommendation**: Either remove the parameter and rename to `microphoneIcon()`, or implement per-state rendering.
- **Effort**: Quick Win

### [x] [H8] Dead code: `StatusDot` and `PromptSection` defined but never used `[T1]`
- **File**: `MenuBar/PopoverView.swift:628–658` (StatusDot), `662–686` (PromptSection)
- **Auditor**: code-quality-auditor, ux-auditor
- **Issue**: Both are fully implemented but never instantiated anywhere. `PromptSection` was replaced by `GeneralPromptSection`.
- **Recommendation**: Delete both.
- **Effort**: Quick Win

### [x] [H9] LLM download state machine duplicated between `SetupView` and `LLMModelSection` `[T1]`
- **File**: `MenuBar/PopoverView.swift:97–103` vs `1303–1307`
- **Auditor**: code-quality-auditor
- **Issue**: Both views independently manage `isDownloading`, `downloadingModelId`, `llmDownloadProgress`, `downloadTask` and duplicate the download/cancel async task pattern. Bug fix in one location may not be applied to the other.
- **Recommendation**: Move LLM download state into `LLMProcessor` (or a dedicated `LLMDownloadManager`) and expose `@Published` progress. Both views observe it.
- **Effort**: Moderate

### [x] [H10] Polish error strings in non-UI Swift code — violates project convention `[T1]`
- **File**: `TextProcessing/LLMProcessor.swift:12–18`, `Transcription/TranscriptionEngine.swift:8–15`
- **Auditor**: code-quality-auditor, swift-objc-auditor
- **Issue**: Per CLAUDE.md: "Polish appears only in UI strings (.strings files)." `LLMError` and `TranscriptionError` have `errorDescription` returning Polish strings directly in Swift source, bypassing localization.
- **Recommendation**: Use `String(localized:)` with English default values. Add Polish translations to `.strings` file.
- **Effort**: Quick Win

### [x] [H11] `AppPickerSheet` and `AppSTTLanguagePickerSheet` are near-duplicate sheets `[T1]`
- **File**: `MenuBar/PopoverView.swift:1203–1294` and `1835–1958`
- **Auditor**: code-quality-auditor, ios-auditor, ux-auditor
- **Issue**: Both implement the same search-filtered app list pattern but with different implementations. `AppSTTLanguagePickerSheet.loadApps()` scans 3 hardcoded dirs synchronously on main thread; `AppPickerSheet.loadInstalledApps()` uses `DispatchQueue.global`. They return different app lists. UI sizing also differs (300 vs 320 width).
- **Recommendation**: Extract a shared `AppPickerSheet<Action>` parameterized by title and `onSelect` closure. Implement `loadInstalledApps` once on a background thread.
- **Effort**: Moderate

### [x] [H12] Deleting active STT model doesn't update selection — next recording errors `[T3]`
- **File**: `MenuBar/PopoverView.swift:2001–2007`
- **Auditor**: ux-auditor
- **Issue**: Trash button on active STT model calls `deleteModel(model.id)` with no guard. `activeModelId` still holds the deleted ID. Next hotkey press triggers warmup for a non-existent model → error state. Also triggers `isSetupComplete = false` → redirects to SetupView.
- **Recommendation**: Prevent deletion of active model with an alert, or auto-select the next available model.
- **Effort**: Quick Win

## Medium Priority Findings

### [ ] [M1] PopoverView.swift is ~2167 lines — god file with 28+ types `[T1]`
- **File**: `MenuBar/PopoverView.swift`
- **Auditor**: code-quality-auditor, swift-objc-auditor, ios-auditor
- **Issue**: Contains onboarding, settings, model management, HuggingFace search, per-app prompts, hotkey recorder, downloaded-models browser, uninstall flow, NSTextView subclass, and NSViewRepresentable. 28+ types in one file.
- **Recommendation**: Split by MARK boundary: `SetupView.swift`, `STTModelSection.swift`, `LLMModelSection.swift`, `PromptEditorComponents.swift`, `AppPickerSheet.swift`. PopoverView becomes a thin compositor under 150 lines.
- **Effort**: Significant

### [x] [M2] `@StateObject` used for externally-owned singleton `[T3]`
- **File**: `MenuBar/PopoverView.swift:8`
- **Auditor**: ios-auditor
- **Issue**: `@StateObject private var permissions = PermissionsManager.shared` wraps a pre-existing singleton as if PopoverView owns it. `@StateObject` is for objects whose lifetime is tied to the view.
- **Recommendation**: Change to `@ObservedObject`.
- **Effort**: Quick Win

### [x] [M3] `DispatchQueue.main.async/asyncAfter` mixed with `@MainActor` isolation `[T3]`
- **File**: `DictationPipeline.swift:304`, `MenuBarManager.swift:74`, `AudioRecorder.swift:72`, `FloatingIndicatorManager.swift:75`
- **Auditor**: ios-auditor, swift-objc-auditor
- **Issue**: These `@MainActor`-isolated classes dispatch work via `DispatchQueue.main.async`. Mixes two concurrency models. Cannot be cancelled, no structured lifetime.
- **Recommendation**: Replace with `Task { @MainActor in }`. For delayed work use `Task { try? await Task.sleep(for: .seconds(n)); ... }`.
- **Effort**: Moderate

### [x] [M4] Magic modifier bitmask literals in `RecordingSettingsSection` `[T1]`
- **File**: `MenuBar/PopoverView.swift:762–765`
- **Auditor**: code-quality-auditor, swift-objc-auditor
- **Issue**: Raw integers `1048576`, `524288`, `262144`, `131072` for modifier flags. Opaque to anyone who doesn't know the bitmask layout.
- **Recommendation**: Use `NSEvent.ModifierFlags(rawValue: UInt(modifiers))` and `.contains(.command)` etc.
- **Effort**: Quick Win

### [x] [M5] Duplicate `appIcon(for:)` method in two sibling views `[T1]`
- **File**: `MenuBar/PopoverView.swift:1197–1200` and `1693–1696`
- **Auditor**: code-quality-auditor
- **Issue**: Identical `appIcon(for bundleId:) -> NSImage?` in `AppSTTLanguageRow` and `AppPromptRow`.
- **Recommendation**: Extract to a file-private free function.
- **Effort**: Quick Win

### [x] [M6] Duplicate `ghostSuffix`/`acceptGhost()` in two views `[T1]`
- **File**: `MenuBar/PopoverView.swift:1518–1520,1571–1574` and `1620–1622,1687–1691`
- **Auditor**: code-quality-auditor
- **Issue**: `GeneralPromptSection` and `AppPromptRow` both contain identical ghost completion logic.
- **Recommendation**: Extract `ghostCompletionFor(_ text: String) -> String?` helper.
- **Effort**: Quick Win

### [x] [M7] `TranscriptionEngine.loadModel(fromFolder:)` duplicates loading boilerplate `[T1]`
- **File**: `Transcription/TranscriptionEngine.swift:47–67`
- **Auditor**: code-quality-auditor
- **Issue**: Both `loadModel` overloads repeat guard/isLoading/defer/reset boilerplate. Only difference is `WhisperKitConfig` construction.
- **Recommendation**: Extract shared logic into `private loadWhisperKit(_ config:modelId:)`.
- **Effort**: Quick Win

### [x] [M8] `DownloadedModelsSection` calls `AppSettings.shared` instead of injected `@EnvironmentObject` `[T1]`
- **File**: `MenuBar/PopoverView.swift:1983`
- **Auditor**: code-quality-auditor
- **Issue**: `AppSettings.shared.sttModelId = model.id` while the view has `@EnvironmentObject var settings: AppSettings`. Bypasses the injected instance.
- **Recommendation**: Replace with `settings.sttModelId`.
- **Effort**: Quick Win

### [x] [M9] `WhisperModelManager.totalSizeOnDisk()` uses static estimates, not real disk sizes `[T1]`
- **File**: `Transcription/WhisperModelManager.swift:149–155`
- **Auditor**: code-quality-auditor
- **Issue**: Sums hardcoded `sizeBytes` from `defaultModels` instead of scanning actual cache directory. Combined with `DownloadedModelsManager.totalSizeOnDisk` (which uses real sizes) in the UI, giving mixed accuracy.
- **Recommendation**: Implement using `directorySize` approach, scanning the WhisperKit model folder.
- **Effort**: Moderate

### [x] [M10] `observePermissions()` has redundant `stop()` call on already-stopped manager `[T1]`
- **File**: `DictationPipeline.swift:98–110`
- **Auditor**: code-quality-auditor
- **Issue**: `if !self.hotkeyManager.isListening { self.hotkeyManager.stop(); self.setupHotkey() }` — the `stop()` is always a no-op since the guard already proves `isListening == false`. Comment says "restarting" but code is just starting.
- **Recommendation**: Remove the `stop()` call: `if !hotkeyManager.isListening { setupHotkey() }`.
- **Effort**: Quick Win

### [x] [M11] `PasteManager` uses hardcoded timing delays with no justification `[T1]`
- **File**: `HotkeyAndPaste/PasteManager.swift:27,31`
- **Auditor**: code-quality-auditor, ios-auditor
- **Issue**: Magic `0.15` and `0.5` second delays. No named constants, no documentation of why these values were chosen.
- **Recommendation**: Extract as named constants with brief comments. Consider longer baseline on loaded systems.
- **Effort**: Quick Win

### [x] [M12] `GeneralPromptSection` and `AppPromptRow` maintain dual-source-of-truth `localPrompt` `[T2]`
- **File**: `MenuBar/PopoverView.swift:1516,1617`
- **Auditor**: swift-objc-auditor
- **Issue**: Both maintain `@State var localPrompt` that shadows `settings.llmPrompt` / `appPrompt.prompt`. Sync via `.onAppear` + `.onChange` creates double-write churn and stale state risk.
- **Recommendation**: Bind directly to `$settings.llmPrompt` in `GeneralPromptSection`. For `AppPromptRow`, use index-based `Binding`.
- **Effort**: Moderate

### [x] [M13] `ModelBrowser` misplaced on `DictationPipeline` — never used by pipeline `[T1]`
- **File**: `DictationPipeline.swift:29`
- **Auditor**: code-quality-auditor
- **Issue**: `let modelBrowser = ModelBrowser()` is on `DictationPipeline` but accessed only from `LLMModelSection`. Pipeline is a recording orchestrator; owning a HuggingFace search model violates SRP.
- **Recommendation**: Move to `LLMModelSection` as `@StateObject`, or to its own singleton.
- **Effort**: Quick Win

### [x] [M14] App picker shows blank list while loading — no loading state `[T3]`
- **File**: `MenuBar/PopoverView.swift:1275–1293,1908–1957`
- **Auditor**: ux-auditor
- **Issue**: Both picker sheets scan filesystem on `.onAppear`. During 200–500ms scan, `apps` is empty, scroll view shows blank area. No loading indicator.
- **Recommendation**: Add `@State private var isLoading = true` flag. Show `ProgressView()` while loading. Add empty-state text.
- **Effort**: Quick Win

### [x] [M15] LLM search: all results disabled when any download is in progress `[T3]`
- **File**: `MenuBar/PopoverView.swift:1419`
- **Auditor**: ux-auditor
- **Issue**: `.disabled(isDownloaded || isDownloading)` uses outer `isDownloading` flag, disabling every non-downloaded row during any download. Combined with `browser.clearSearch()` at download start, search disappears entirely.
- **Recommendation**: Disable only the specific row being downloaded. Don't clear search on download start.
- **Effort**: Quick Win

### [x] [M16] Error state and recording state both use `.red` — not visually distinguished `[T3]`
- **File**: `MenuBar/PopoverView.swift:604,615–625`
- **Auditor**: ux-auditor
- **Issue**: Both `.recording` and `.error` use red as `stateColor`. User must infer from context whether things are working or broken. Error shows raw `localizedDescription` which may be an internal system message.
- **Recommendation**: Use a distinct color for errors. Add error icon. Map common errors to user-friendly strings.
- **Effort**: Moderate

### [x] [M17] SetupView Step 3 `isDone` check uses stale `llmDownloadedModelId` key `[T3]`
- **File**: `MenuBar/PopoverView.swift:101,201`
- **Auditor**: ux-auditor
- **Issue**: `llmDownloadedModelId` is never cleared — even when model is deleted. Step 3 shows permanent green checkmark regardless of actual state.
- **Recommendation**: Cross-reference against `pipeline.downloadedModelsManager.downloadedModels`.
- **Effort**: Quick Win

### [x] [M18] Hardcoded recommended model ID in `SetupModelRow` `[T1]`
- **File**: `MenuBar/PopoverView.swift:435–437`
- **Auditor**: code-quality-auditor
- **Issue**: `model.id == "openai_whisper-large-v3_turbo"` — if default model changes, this string goes stale. Already encoded in `WhisperModelManager.defaultModels` by position.
- **Recommendation**: Add `var isRecommended: Bool` to `WhisperModelInfo`, matching `LLMModelOption.recommended` pattern.
- **Effort**: Quick Win

## Low Priority Findings

### [x] [L1] `WhisperModelManager.deleteModel()` does not delete files from disk `[T3]`
- **File**: `Transcription/WhisperModelManager.swift:141–147`
- **Auditor**: ios-auditor
- **Issue**: Removes model ID from `downloadedModelIds` (UserDefaults) but does not delete model files (~1GB+). File deletion only happens through `DownloadedModelsManager.deleteModel()`.
- **Recommendation**: Route delete through a method that handles both ID registry and filesystem cleanup.
- **Effort**: Moderate

### [x] [L2] Deprecated SwiftUI modifiers: `.foregroundColor()` and `.cornerRadius()` (~68 uses) `[T3]`
- **File**: `MenuBar/PopoverView.swift` (throughout)
- **Auditor**: ios-auditor
- **Issue**: macOS 26.0 deployment target — `.foregroundStyle()` and `.clipShape(RoundedRectangle(...))` are unconditionally available.
- **Recommendation**: Find-and-replace to modern APIs.
- **Effort**: Quick Win

### [x] [L3] `AppPrompt.resolve(with:)` defined but never called `[T1]`
- **File**: `Settings/AppSettings.swift:79–86`
- **Auditor**: code-quality-auditor, swift-objc-auditor
- **Issue**: Dead code. Actual prompt resolution reimplemented in `LLMProcessor.cleanText`.
- **Recommendation**: Delete, or use it from `LLMProcessor` to eliminate duplicate branching.
- **Effort**: Quick Win

### [x] [L4] Version string `CFBundleShortVersionString` duplicated in SetupView and FooterSection `[T1]`
- **File**: `MenuBar/PopoverView.swift:282–284,2105`
- **Auditor**: code-quality-auditor
- **Issue**: Both construct version string inline with raw key string.
- **Recommendation**: Extract `var appVersion: String` computed property.
- **Effort**: Quick Win

### [x] [L5] Missing `PrivacyInfo.xcprivacy` for UserDefaults required-reason API `[T3]`
- **File**: `project.yml` / `Resources/`
- **Auditor**: ios-auditor
- **Issue**: App uses `UserDefaults.standard` — Apple requires `PrivacyInfo.xcprivacy` declaring `NSPrivacyAccessedAPITypes` with reason code `CA92.1`.
- **Recommendation**: Add `PrivacyInfo.xcprivacy` to `Resources/` and declare in `project.yml`.
- **Effort**: Quick Win

### [x] [L6] `NSMicrophoneUsageDescription` in Info.plist is Polish-only `[T3]`
- **File**: `Resources/Info.plist:29–30`
- **Auditor**: ios-auditor
- **Issue**: Hardcoded Polish string. On English system, macOS permission dialog shows Polish text.
- **Recommendation**: Use English as canonical plist value; provide Polish via `InfoPlist.strings`.
- **Effort**: Quick Win

### [x] [L7] `CURRENT_PROJECT_VERSION` hardcoded to `"1"` — never incremented `[T3]`
- **File**: `project.yml:42`
- **Auditor**: ios-auditor
- **Issue**: `CFBundleVersion` always `"1"`. Sparkle may not determine update order by build number alone.
- **Recommendation**: Auto-increment in release script alongside `MARKETING_VERSION`.
- **Effort**: Quick Win

### [x] [L8] `MenuBarManager.shared` is `static weak var` — can become nil `[T3]`
- **File**: `MenuBar/MenuBarManager.swift:7`
- **Auditor**: ios-auditor, swift-objc-auditor
- **Issue**: If `AppDelegate.menuBarManager` is cleared, `shared` silently becomes nil. All callers use `?.` (safe) but popover would silently not appear.
- **Recommendation**: Make `shared` a strong `static var` or document the intent.
- **Effort**: Quick Win

### [x] [L9] Version button in footer has no visible affordance that it's tappable `[T3]`
- **File**: `MenuBar/PopoverView.swift:2104–2111`
- **Auditor**: ux-auditor
- **Issue**: Version "Wersja: 1.x.x" is a `.plain` Button with `.secondary` color. No hover cue. Users won't discover it checks for updates.
- **Recommendation**: Show underline on hover or add explicit "Check for updates" link.
- **Effort**: Quick Win

### [x] [L10] Download arrow icon `.foregroundStyle(.white)` invisible in light mode `[T3]`
- **File**: `MenuBar/PopoverView.swift:368,492,1053`
- **Auditor**: ux-auditor
- **Issue**: White icon on near-white `.quaternarySystemFill` background in light mode.
- **Recommendation**: Use `.foregroundStyle(Color("AccentColor"))` to match other action affordances.
- **Effort**: Quick Win

## Test Coverage Gap Analysis

| Directory | Files | Test Coverage | Priority |
|-----------|-------|---------------|----------|
| Audio/ | 1 | None | Medium |
| DictationPipeline | 1 | None | High |
| FloatingIndicator/ | 1 | None | Medium |
| HotkeyAndPaste/ | 3 | None | High |
| MenuBar/ | 3 | None | Medium |
| ModelBrowser/ | 2 | None | Low |
| Settings/ | 3 | None | Medium |
| TextProcessing/ | 1 | None | High |
| Transcription/ | 2 | None | High |

**Note**: Project has no tests (manual QA only per CLAUDE.md). Test addition not recommended without explicit user request.

## Suggested Improvements

| Area | Description | Impact |
|------|-------------|--------|
| File structure | Split PopoverView.swift into 5-6 focused files | Navigation, reviewability, maintainability |
| Download management | Centralize LLM download state into a dedicated manager | Eliminates duplication, consistent error handling |
| Concurrency | Annotate `AppSettings` with `@MainActor`, cache values for tap callback | Eliminates data races |
| Logging | Replace `dlog()` with persistent FileHandle or `os.Logger` | Performance under load |
| App picker | Extract shared `AppPickerSheet` component | Eliminates 200+ lines duplication |
| Prompt editor | Extract shared ghost-completion logic | Consistency, single source of truth |
