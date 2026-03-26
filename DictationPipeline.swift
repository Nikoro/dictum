import Foundation
import SwiftUI
import Combine

func dlog(_ msg: String) {
    let line = "[\(Date())] \(msg)\n"
    let path = "/tmp/dictum.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
}

@MainActor
final class DictationPipeline: ObservableObject {
    static let shared = DictationPipeline()

    let audioRecorder = AudioRecorder()
    let hotkeyManager = GlobalHotkeyManager.shared
    let whisperModelManager = WhisperModelManager.shared
    let downloadedModelsManager = DownloadedModelsManager.shared
    let modelBrowser = ModelBrowser()

    private let settings = AppSettings.shared
    private let permissions = PermissionsManager.shared
    private var isRecording = false
    private var isCancelled = false
    private var permissionsCancellable: AnyCancellable?

    private init() {
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
                    self.hotkeyManager.stop()
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
            let _ = audioRecorder.stopRecording()
            isRecording = false
        }
        isCancelled = true
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
        do {
            try audioRecorder.startRecording()
            isRecording = true
            settings.appState = .recording
            dlog("[Dictum] recording started, showing floating indicator")
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
            dlog("[Dictum] transcribing \(samples.count) samples...")
            let rawText = try await TranscriptionEngine.shared.transcribe(audioSamples: samples)
            guard !isCancelled else { return }
            dlog("[Dictum] transcription result: '\(rawText)'")
            settings.lastTranscription = rawText

            guard !rawText.isEmpty else {
                settings.appState = .idle
                FloatingIndicatorManager.shared.hide()
                return
            }

            // LLM cleanup (if enabled)
            let finalText: String
            if settings.llmCleanupEnabled {
                settings.appState = .processingLLM
                do {
                    // Lazy load LLM if needed
                    let llmLoaded = await LLMProcessor.shared.isModelLoaded
                    if !llmLoaded {
                        try await LLMProcessor.shared.loadModel(settings.llmModelId)
                    }

                    dlog("[Dictum] LLM prompt: '\(settings.llmPrompt)'")
                    dlog("[Dictum] LLM input: '\(rawText)'")
                    finalText = try await LLMProcessor.shared.cleanText(
                        rawText: rawText,
                        systemPrompt: settings.llmPrompt
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
            dlog("[Dictum] final text: '\(finalText)', pasting...")

            // Auto-paste and hide immediately
            PasteManager.shared.pasteText(finalText)
            FloatingIndicatorManager.shared.hide()
            settings.appState = .idle
            dlog("[Dictum] done!")
        } catch {
            dlog("[Dictum] ERROR: \(error)")
            FloatingIndicatorManager.shared.hide()
            settings.appState = .error(error.localizedDescription)
            // Clear error after 3s
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if case .error = self?.settings.appState {
                    self?.settings.appState = .idle
                }
            }
        }
    }
}
