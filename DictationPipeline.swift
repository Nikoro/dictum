import AppKit
import Foundation

@MainActor
final class DictationPipeline {
    static let shared = DictationPipeline()

    let audioRecorder = AudioRecorder()
    let hotkeyMonitor = GlobalHotkeyMonitor.shared

    private let settings = AppSettings.shared
    private let runtimeState = AppRuntimeState.shared
    private let permissionStore = SystemPermissionStore.shared
    private let whisperModelStore = WhisperModelStore.shared
    private let modelWarmup = ModelWarmupCoordinator.shared
    private var isRecording = false
    private var isCancelled = false
    private var isAborted: Bool {
        isCancelled || Task.isCancelled
    }

    private var errorResetTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?
    private var recordingTimeoutTask: Task<Void, Never>?
    private var frontmostApp: NSRunningApplication?
    private(set) var pendingSelectedContext: String?

    func setPendingContext(_ text: String?) {
        pendingSelectedContext = text
    }

    private var dictationContext: DictationContext?

    private init() {}

    func start() {
        setupHotkey()
        observePermissions()
        modelWarmup.preloadModels()
    }

    private func observePermissions() {
        let permissionStore = permissionStore
        Task { [weak self] in
            var wasGranted = false
            for await isGranted in Observations({ permissionStore.accessibilityGranted }) {
                defer { wasGranted = isGranted }
                guard isGranted, !wasGranted, let self else { continue }
                dlog("[Dictum] Accessibility granted via SystemPermissionStore, restarting hotkey")
                if !hotkeyMonitor.isListening {
                    setupHotkey()
                }
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
        if settings.recordingMode == .hold, isRecording {
            await stopRecordingAndProcess()
        }
    }

    func cancelOperation() {
        dlog("[Dictum] cancel requested")
        if isRecording {
            _ = audioRecorder.stopRecording()
            isRecording = false
        }
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = nil
        // Edge case: cancel the work itself, or transcription and generation keep the GPU busy
        // after the pill has disappeared.
        processingTask?.cancel()
        processingTask = nil
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

        guard requireDownloadedSTTModel() else { return }
        dlog("[Dictum] startRecording called")

        if let ctx = pendingSelectedContext {
            dlog("[Dictum] pending selected context: \(ctx.count) chars")
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
            startRecordingTimeout()
        } catch {
            dlog("[Dictum] startRecording error: \(error)")
            runtimeState.appState = .error(
                "\(String(localized: "error.mic", defaultValue: "Cannot start microphone:")) " +
                    error.localizedDescription
            )
        }
    }

    private func requireDownloadedSTTModel() -> Bool {
        guard !whisperModelStore.downloadedModelIds.contains(settings.sttModelId) else { return true }
        dlog("[Dictum] STT model not downloaded, showing popover")
        runtimeState.appState = .error(String(
            localized: "error.download.stt",
            defaultValue: "Download STT model in settings"
        ))
        MenuBarController.shared?.showPopover()
        return false
    }

    func stopRecordingAndProcess() async {
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = nil

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await processStoppedRecording()
        }
        processingTask = task
        await task.value
        if processingTask == task {
            processingTask = nil
        }
    }

    // Edge case: a key-up can be lost (e.g. the tap was disabled mid-press); stop and transcribe
    // rather than record forever.
    private func startRecordingTimeout() {
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(AudioRecorder.maxRecordingSeconds))
            guard !Task.isCancelled, let self, isRecording else { return }
            dlog("[Dictum] recording hit the \(AudioRecorder.maxRecordingSeconds)s cap, stopping")
            await stopRecordingAndProcess()
        }
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
            try await process(samples)
        } catch {
            handleProcessingError(error)
            throw error
        }
    }
}

@MainActor
private extension DictationPipeline {
    func waitForWarmupIfNeeded() async {
        guard modelWarmup.isWarmingUp else { return }
        dlog("[Dictum] waiting for warmup to finish...")
        runtimeState.appState = .warmingUp
        FloatingIndicatorPanelController.shared.captureTargetApp()
        FloatingIndicatorPanelController.shared.show(audioRecorder: audioRecorder)
        await modelWarmup.waitForWarmup()
    }

    func process(_ samples: [Float]) async throws {
        let processor = DictationProcessor(
            targetAppAtRecordingStart: frontmostApp,
            selectedTextAtHotkeyPress: pendingSelectedContext
        ) { [weak self] in self?.isAborted ?? true }
        let rawText = try await processor.transcribe(samples: samples)
        guard !rawText.isEmpty else {
            transitionToIdleAfterEmptyRecording()
            return
        }
        let (finalText, context) = await processor.finalize(rawText)
        pendingSelectedContext = nil
        dictationContext = context
        guard !isAborted else { return }
        runtimeState.lastCleanedText = finalText
        deliverFinalText(finalText)
        finishProcessing()
    }

    func deliverFinalText(_ finalText: String) {
        let isContextMode = dictationContext?.selectedText != nil
        if isContextMode {
            dlog("[Dictum] final text (context mode): \(finalText.count) chars, copying to clipboard")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(finalText, forType: .string)
            return
        }

        dlog("[Dictum] final text: \(finalText.count) chars, pasting...")
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
            if case .error = runtimeState.appState {
                runtimeState.appState = .idle
            }
            errorResetTask = nil
        }
    }
}
