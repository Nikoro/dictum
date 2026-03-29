import Foundation
import SwiftUI
import AppKit
import Combine

private let _logger = DictumLogger()

func dlog(_ msg: String) {
    _logger.log(msg)
}

private final class DictumLogger: @unchecked Sendable {
    private let lock = NSLock()
    private var handle: FileHandle?
    private let path: String

    init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Dictum")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        self.path = logsDir.appendingPathComponent("dictum.log").path
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        self.handle = FileHandle(forWritingAtPath: path)
        self.handle?.seekToEndOfFile()
    }

    func log(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        let data = Data(line.utf8)
        lock.lock()
        defer { lock.unlock() }
        if handle == nil {
            handle = FileHandle(forWritingAtPath: path)
            handle?.seekToEndOfFile()
        }
        handle?.write(data)
    }
}

@MainActor
final class DictationPipeline: ObservableObject {
    static let shared = DictationPipeline()

    let audioRecorder = AudioRecorder()
    let hotkeyManager = GlobalHotkeyManager.shared
    let whisperModelManager = WhisperModelManager.shared
    let downloadedModelsManager = DownloadedModelsManager.shared

    private let settings = AppSettings.shared
    private let permissions = PermissionsManager.shared
    private var isRecording = false
    private var isCancelled = false
    private(set) var isWarmedUp = false
    private var warmupTask: Task<Void, Never>?
    private var targetBundleId: String?
    /// Selected text captured synchronously from the event tap callback, before any async dispatch.
    var pendingSelectedContext: String?
    @Published var llmDownloadError: String?
    @Published var llmIsDownloading = false
    @Published var llmDownloadingModelId: String?
    @Published var llmDownloadProgress: Double = 0
    private var llmDownloadTask: Task<Void, Never>?
    private var selectedContext: String?
    private var permissionsCancellable: AnyCancellable?
    private var whisperSink: AnyCancellable?
    private var downloadedModelsSink: AnyCancellable?

    private init() {
        whisperSink = whisperModelManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        downloadedModelsSink = downloadedModelsManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        setupHotkey()
        observePermissions()
        preloadSTTModel()
    }

    private func preloadSTTModel() {
        guard whisperModelManager.downloadedModelIds.contains(settings.sttModelId) else { return }
        Task {
            let loaded = await TranscriptionEngine.shared.isModelLoaded
            if !loaded {
                dlog("[Dictum] preloading STT model: \(settings.sttModelId)")
                try? await TranscriptionEngine.shared.loadModel(settings.sttModelId)
                dlog("[Dictum] STT model preloaded")
            }
            // Also preload LLM if enabled and downloaded
            if settings.llmCleanupEnabled {
                let llmLoaded = await LLMProcessor.shared.isModelLoaded
                if !llmLoaded {
                    dlog("[Dictum] preloading LLM model: \(settings.llmModelId)")
                    try? await LLMProcessor.shared.loadModel(settings.llmModelId)
                    dlog("[Dictum] LLM model preloaded")
                }
            }
            warmUpModels()
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
        permissionsCancellable = permissions.$accessibilityGranted
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self else { return }
                dlog("[Dictum] Accessibility granted via PermissionsManager, restarting hotkey")
                if !self.hotkeyManager.isListening {
                    self.setupHotkey()
                }
            }
    }

    func setupHotkey() {
        hotkeyManager.start(
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
        isCancelled = true
        selectedContext = nil
        settings.appState = .idle
        FloatingIndicatorManager.shared.hide()
    }

    func startRecording() {
        guard !isRecording else { return }

        // Guard: STT model must be downloaded first
        if !whisperModelManager.downloadedModelIds.contains(settings.sttModelId) {
            dlog("[Dictum] STT model not downloaded, showing popover")
            settings.appState = .error(String(localized: "error.download.stt", defaultValue: "Download STT model in settings"))
            // Open the menu bar popover so user sees the setup screen
            MenuBarManager.shared?.showPopover()
            return
        }

        dlog("[Dictum] startRecording called")

        // Use selected text captured synchronously from the event tap
        selectedContext = pendingSelectedContext
        pendingSelectedContext = nil
        if let ctx = selectedContext {
            dlog("[Dictum] using selected context (\(ctx.count) chars): '\(ctx.prefix(100))...'")
        }

        do {
            try audioRecorder.startRecording()
            isRecording = true
            settings.appState = .recording
            targetBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            dlog("[Dictum] recording started, target app: \(targetBundleId ?? "nil"), showing floating indicator")
            FloatingIndicatorManager.shared.captureTargetApp()
            FloatingIndicatorManager.shared.show(audioRecorder: audioRecorder)
        } catch {
            dlog("[Dictum] startRecording error: \(error)")
            settings.appState = .error("\(String(localized: "error.mic", defaultValue: "Cannot start microphone:")) \(error.localizedDescription)")
        }
    }

    func stopRecordingAndProcess() async {
        guard isRecording else { return }
        isCancelled = false
        let samples = audioRecorder.stopRecording()
        isRecording = false
        // Don't hide pill — it stays visible showing pipeline status
        dlog("[Dictum] stopRecording, samples=\(samples.count)")

        // Wait for warmup to finish if still running
        if !isWarmedUp, let task = warmupTask {
            dlog("[Dictum] waiting for warmup to finish...")
            settings.appState = .warmingUp
            FloatingIndicatorManager.shared.captureTargetApp()
            FloatingIndicatorManager.shared.show(audioRecorder: audioRecorder)
            await task.value
        }

        guard !samples.isEmpty else {
            dlog("[Dictum] no samples, going idle")
            settings.appState = .idle
            FloatingIndicatorManager.shared.hide()
            return
        }

        // Transcribe
        settings.appState = .transcribing
        do {
            // Lazy load STT model if needed
            let sttLoaded = await TranscriptionEngine.shared.isModelLoaded
            if !sttLoaded {
                dlog("[Dictum] loading STT model: \(settings.sttModelId)")
                try await TranscriptionEngine.shared.loadModel(settings.sttModelId)
                dlog("[Dictum] STT model loaded")
            }

            guard !isCancelled else { return }
            let sttLanguage = settings.resolveSTTLanguage(for: targetBundleId)
            dlog("[Dictum] transcribing \(samples.count) samples, language: \(sttLanguage ?? "auto")...")
            let rawText = try await TranscriptionEngine.shared.transcribe(audioSamples: samples, language: sttLanguage)
            guard !isCancelled else { return }
            dlog("[Dictum] transcription result: '\(rawText)'")
            settings.lastTranscription = rawText

            guard !rawText.isEmpty else {
                settings.appState = .idle
                FloatingIndicatorManager.shared.hide()
                return
            }

            // LLM cleanup (if enabled and a prompt resolves)
            let finalText: String
            let resolvedPrompt = settings.llmCleanupEnabled ? settings.resolvePrompt(for: targetBundleId) : nil
            if settings.llmCleanupEnabled, let prompt = resolvedPrompt {
                settings.appState = .processingLLM
                do {
                    // Lazy load LLM if needed
                    let llmLoaded = await LLMProcessor.shared.isModelLoaded
                    if !llmLoaded {
                        try await LLMProcessor.shared.loadModel(settings.llmModelId)
                    }

                    dlog("[Dictum] LLM prompt for \(targetBundleId ?? "general"): '\(prompt)'")
                    dlog("[Dictum] LLM input: '\(rawText)', context: \(selectedContext != nil ? "yes" : "none")")
                    finalText = try await LLMProcessor.shared.cleanText(
                        rawText: rawText,
                        prompt: prompt,
                        context: selectedContext
                    )
                    dlog("[Dictum] LLM raw output: '\(finalText)'")
                } catch {
                    dlog("[Dictum] LLM cleanup failed, using raw text: \(error)")
                    finalText = rawText
                }
            } else {
                finalText = rawText
            }

            guard !isCancelled else { return }
            settings.lastCleanedText = finalText

            if selectedContext != nil {
                // Context mode: put result in clipboard, user pastes manually
                dlog("[Dictum] final text (context mode): '\(finalText)', copying to clipboard")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(finalText, forType: .string)
            } else {
                // Normal mode: auto-paste
                dlog("[Dictum] final text: '\(finalText)', pasting...")
                PasteManager.shared.pasteText(finalText)
            }

            FloatingIndicatorManager.shared.hide()
            selectedContext = nil
            settings.appState = .idle
            dlog("[Dictum] done!")
        } catch {
            dlog("[Dictum] ERROR: \(error)")
            FloatingIndicatorManager.shared.hide()
            settings.appState = .error(error.localizedDescription)
            // Clear error after 3s
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                if case .error = self?.settings.appState {
                    self?.settings.appState = .idle
                }
            }
        }
    }

    // MARK: - LLM Download

    func downloadLLMModel(_ modelId: String) {
        llmIsDownloading = true
        llmDownloadingModelId = modelId
        llmDownloadProgress = 0
        llmDownloadError = nil
        llmDownloadTask = Task {
            do {
                try await LLMProcessor.shared.loadModel(modelId) { [weak self] progress in
                    Task { @MainActor in
                        self?.llmDownloadProgress = progress.fractionCompleted
                    }
                }
                settings.llmModelId = modelId
                downloadedModelsManager.scanDownloadedModels()
            } catch {
                if !Task.isCancelled {
                    llmDownloadError = error.localizedDescription
                }
            }
            llmIsDownloading = false
            llmDownloadingModelId = nil
            llmDownloadProgress = 0
            llmDownloadTask = nil
        }
    }

    func cancelLLMDownload() {
        llmDownloadTask?.cancel()
        llmDownloadTask = nil
        llmIsDownloading = false
        llmDownloadingModelId = nil
        llmDownloadProgress = 0
    }
}
