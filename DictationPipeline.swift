import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
final class DictationPipeline: ObservableObject {
    static let shared = DictationPipeline()

    let audioRecorder = AudioRecorder()
    let hotkeyMonitor = GlobalHotkeyMonitor.shared
    let whisperModelStore = WhisperModelStore.shared
    let downloadedLLMModelStore = DownloadedLLMModelStore.shared

    private let settings = AppSettings.shared
    private let runtimeState = AppRuntimeState.shared
    private let permissionStore = SystemPermissionStore.shared
    private let llmModelDownloadController = LLMModelDownloadController()
    private var isRecording = false
    private var isCancelled = false
    private(set) var isWarmedUp = false
    private var warmupTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?
    private var errorResetTask: Task<Void, Never>?
    private var frontmostApp: NSRunningApplication?
    /// Selected text captured synchronously from the event tap callback, before any async dispatch.
    private(set) var pendingSelectedContext: String?

    func setPendingContext(_ text: String?) {
        pendingSelectedContext = text
    }
    private var dictationContext: DictationContext?
    private var permissionsCancellable: AnyCancellable?
    private var whisperSink: AnyCancellable?
    private var downloadedModelsSink: AnyCancellable?
    private var llmDownloadSink: AnyCancellable?

    var llmDownloadError: String? {
        get { llmModelDownloadController.downloadError }
        set { llmModelDownloadController.downloadError = newValue }
    }

    var llmIsDownloading: Bool { llmModelDownloadController.isDownloading }
    var llmDownloadingModelId: String? { llmModelDownloadController.downloadingModelId }
    var llmDownloadProgress: Double { llmModelDownloadController.downloadProgress }

    private init() {
        whisperSink = whisperModelStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        downloadedModelsSink = downloadedLLMModelStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        llmDownloadSink = llmModelDownloadController.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        setupHotkey()
        observePermissions()
        preloadSTTModel()
    }

    private func preloadSTTModel() {
        guard whisperModelStore.downloadedModelIds.contains(settings.sttModelId) else { return }
        preloadTask = Task {
            do {
                let loaded = await TranscriptionEngine.shared.isModelLoaded
                if !loaded {
                    dlog("[Dictum] preloading STT model: \(settings.sttModelId)")
                    try await TranscriptionEngine.shared.loadModel(settings.sttModelId)
                    dlog("[Dictum] STT model preloaded")
                }
                // Also preload LLM if enabled and downloaded
                if settings.llmCleanupEnabled {
                    let llmLoaded = await LLMProcessor.shared.isModelLoaded
                    if !llmLoaded {
                        dlog("[Dictum] preloading LLM model: \(settings.llmModelId)")
                        try await LLMProcessor.shared.loadModel(settings.llmModelId)
                        dlog("[Dictum] LLM model preloaded")
                    }
                }
                warmUpModels()
            } catch {
                dlog("[Dictum] preload failed: \(error)")
            }
        }
    }

    func warmUpModels() {
        warmupTask?.cancel()
        isWarmedUp = false
        warmupTask = Task {
            dlog("[Dictum] warmup started")
            await withTaskGroup(of: Void.self) { group in
                if await TranscriptionEngine.shared.isModelLoaded {
                    group.addTask { await TranscriptionEngine.shared.warmup() }
                }
                if await LLMProcessor.shared.isModelLoaded {
                    group.addTask { await LLMProcessor.shared.warmup() }
                }
            }
            guard !Task.isCancelled else { return }
            isWarmedUp = true
            dlog("[Dictum] warmup complete")
        }
    }

    private func observePermissions() {
        permissionsCancellable = permissionStore.$accessibilityGranted
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self else { return }
                dlog("[Dictum] Accessibility granted via SystemPermissionStore, restarting hotkey")
                if !self.hotkeyMonitor.isListening {
                    self.setupHotkey()
                }
            }
    }

    func setupHotkey() {
        hotkeyMonitor.start(
            onKeyDown: { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    await self.handleKeyDown()
                }
            },
            onKeyUp: { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    await self.handleKeyUp()
                }
            },
            onCancel: { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.cancelOperation()
                }
            }
        )
    }

    private func handleKeyDown() async {
        dlog("[Dictum] handleKeyDown called, mode=\(settings.recordingMode), isRecording=\(isRecording)")
        switch settings.recordingMode {
        case .hold:
            if !isRecording {
                startRecording()
            }
        case .toggle:
            if isRecording {
                await stopRecordingAndProcess()
            } else {
                startRecording()
            }
        }
    }

    private func handleKeyUp() async {
        if settings.recordingMode == .hold && isRecording {
            await stopRecordingAndProcess()
        }
    }

    func cancelOperation() {
        dlog("[Dictum] cancel requested")
        if isRecording {
            _ = audioRecorder.stopRecording()
            isRecording = false
        }
        hotkeyMonitor.isActive = false
        isCancelled = true
        dictationContext = nil
        frontmostApp = nil
        runtimeState.appState = .idle
        FloatingIndicatorPanelController.shared.hide()
    }

    func startRecording() {
        guard !isRecording else { return }
        errorResetTask?.cancel()
        errorResetTask = nil

        // Guard: STT model must be downloaded first
        if !whisperModelStore.downloadedModelIds.contains(settings.sttModelId) {
            dlog("[Dictum] STT model not downloaded, showing popover")
            runtimeState.appState = .error(String(localized: "error.download.stt", defaultValue: "Download STT model in settings"))
            // Open the menu bar popover so user sees the setup screen
            MenuBarController.shared?.showPopover()
            return
        }

        dlog("[Dictum] startRecording called")

        // Selected text was captured synchronously from the event tap — will be used in context gathering
        if let ctx = pendingSelectedContext {
            dlog("[Dictum] pending selected context (\(ctx.count) chars): '\(ctx.prefix(100))...'")
        }

        do {
            try audioRecorder.startRecording()
            isRecording = true
            hotkeyMonitor.isActive = true
            runtimeState.appState = .recording
            frontmostApp = NSWorkspace.shared.frontmostApplication
            dlog("[Dictum] recording started, target app: \(frontmostApp?.bundleIdentifier ?? "nil"), showing floating indicator")
            FloatingIndicatorPanelController.shared.captureTargetApp()
            FloatingIndicatorPanelController.shared.show(audioRecorder: audioRecorder)
        } catch {
            dlog("[Dictum] startRecording error: \(error)")
            runtimeState.appState = .error(
                "\(String(localized: "error.mic", defaultValue: "Cannot start microphone:")) " +
                error.localizedDescription
            )
        }
    }

    func stopRecordingAndProcess() async {
        try? await processStoppedRecording()
    }

    // MARK: - LLM Download

    func downloadLLMModel(_ modelId: String) {
        llmModelDownloadController.downloadModel(modelId)
    }

    func cancelLLMDownload() {
        llmModelDownloadController.cancelDownload()
    }

    private func processStoppedRecording() async throws {
        guard isRecording else { return }
        isCancelled = false
        let samples = audioRecorder.stopRecording()
        isRecording = false
        hotkeyMonitor.isActive = false
        dlog("[Dictum] stopRecording, samples=\(samples.count)")
        await waitForWarmupIfNeeded()
        guard !samples.isEmpty else {
            transitionToIdleAfterEmptyRecording()
            return
        }
        do {
            let rawText = try await transcribe(samples: samples)
            guard !rawText.isEmpty else {
                transitionToIdleAfterEmptyRecording()
                return
            }
            let finalText = await finalizeText(from: rawText)
            guard !isCancelled else { return }
            runtimeState.lastCleanedText = finalText
            deliverFinalText(finalText)
            finishProcessing()
        } catch {
            handleProcessingError(error)
            throw error
        }
    }
}

@MainActor
private extension DictationPipeline {
    func waitForWarmupIfNeeded() async {
        guard !isWarmedUp, let task = warmupTask else { return }
        dlog("[Dictum] waiting for warmup to finish...")
        runtimeState.appState = .warmingUp
        FloatingIndicatorPanelController.shared.captureTargetApp()
        FloatingIndicatorPanelController.shared.show(audioRecorder: audioRecorder)
        await task.value
    }

    func transcribe(samples: [Float]) async throws -> String {
        runtimeState.appState = .transcribing
        try await ensureSTTModelLoaded()
        guard !isCancelled else { return "" }
        let sttLanguage = settings.resolveSTTLanguage(for: frontmostApp?.bundleIdentifier)
        dlog("[Dictum] transcribing \(samples.count) samples, language: \(sttLanguage ?? "auto")...")
        let rawText = try await TranscriptionEngine.shared.transcribe(audioSamples: samples, language: sttLanguage)
        guard !isCancelled else { return "" }
        dlog("[Dictum] transcription complete, \(rawText.count) chars")
        runtimeState.lastTranscription = rawText
        return rawText
    }

    func ensureSTTModelLoaded() async throws {
        let sttLoaded = await TranscriptionEngine.shared.isModelLoaded
        guard !sttLoaded else { return }
        dlog("[Dictum] loading STT model: \(settings.sttModelId)")
        try await TranscriptionEngine.shared.loadModel(settings.sttModelId)
        dlog("[Dictum] STT model loaded")
    }

    func finalizeText(from rawText: String) async -> String {
        // Gather context — individual sources controlled by settings toggles
        let options = ContextOptions(
            screenshot: settings.contextScreenshot,
            selectedText: settings.contextSelectedText,
            clipboard: settings.contextClipboard
        )
        let hasAnyContextEnabled = options.screenshot || options.selectedText || options.clipboard
        let context: DictationContext?
        if settings.smartContextEnabled && hasAnyContextEnabled {
            let gathered = await ContextGatherer.gather(
                selectedText: pendingSelectedContext,
                frontmostApp: frontmostApp,
                options: options
            )
            context = gathered
            dlog("[Dictum] context: app=\(gathered.appName ?? "nil"), selectedText=\(gathered.selectedText != nil ? "yes" : "no"), screenshot=\(gathered.screenshot != nil ? "yes" : "no"), clipboard=\(gathered.clipboardText != nil || gathered.clipboardImage != nil ? "yes" : "no")")
        } else {
            context = nil
            dlog("[Dictum] smart context disabled, skipping")
        }
        pendingSelectedContext = nil
        dictationContext = context

        guard settings.llmCleanupEnabled else {
            return rawText
        }
        let prompt = settings.resolvePrompt(for: frontmostApp?.bundleIdentifier)
        runtimeState.appState = .processingLLM
        do {
            try await ensureLLMModelLoaded()
            dlog("[Dictum] LLM prompt for \(frontmostApp?.bundleIdentifier ?? "general")")
            dlog("[Dictum] LLM input: '\(rawText)', context: \(context?.selectedText != nil ? "yes" : "none")")
            let cleanedText = try await LLMProcessor.shared.cleanText(
                rawText: rawText,
                prompt: prompt,
                context: context
            )
            dlog("[Dictum] LLM raw output: '\(cleanedText)'")
            return cleanedText
        } catch {
            dlog("[Dictum] LLM cleanup failed, using raw text: \(error)")
            return rawText
        }
    }

    func ensureLLMModelLoaded() async throws {
        let llmLoaded = await LLMProcessor.shared.isModelLoaded
        guard !llmLoaded else { return }
        try await LLMProcessor.shared.loadModel(settings.llmModelId)
    }

    func deliverFinalText(_ finalText: String) {
        if dictationContext?.selectedText != nil {
            // Context mode: put result in clipboard, user pastes manually
            dlog("[Dictum] final text (context mode): '\(finalText)', copying to clipboard")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(finalText, forType: .string)
            return
        }

        // Normal mode: auto-paste
        dlog("[Dictum] final text: '\(finalText)', pasting...")
        ClipboardPasteController.shared.pasteText(finalText)
    }

    func finishProcessing() {
        FloatingIndicatorPanelController.shared.hide()
        dictationContext = nil
        frontmostApp = nil
        runtimeState.appState = .idle
        dlog("[Dictum] done!")
    }

    func transitionToIdleAfterEmptyRecording() {
        dlog("[Dictum] no samples, going idle")
        runtimeState.appState = .idle
        FloatingIndicatorPanelController.shared.hide()
    }

    func handleProcessingError(_ error: Error) {
        dlog("[Dictum] ERROR: \(error)")
        FloatingIndicatorPanelController.shared.hide()
        runtimeState.appState = .error(error.localizedDescription)
        errorResetTask?.cancel()
        errorResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            if case .error = self.runtimeState.appState {
                self.runtimeState.appState = .idle
            }
            self.errorResetTask = nil
        }
    }
}
