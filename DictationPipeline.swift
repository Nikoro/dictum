import Foundation
import SwiftUI
import Combine

@MainActor
final class DictationPipeline: ObservableObject {
    static let shared = DictationPipeline()

    let audioRecorder = AudioRecorder()
    let hotkeyManager = GlobalHotkeyManager.shared
    let whisperModelManager = WhisperModelManager.shared
    let downloadedModelsManager = DownloadedModelsManager.shared
    let modelBrowser = ModelBrowser()

    private let settings = AppSettings.shared
    private var isRecording = false

    private init() {
        setupHotkey()
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
            }
        )
    }

    private func handleKeyDown() async {
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

    func startRecording() {
        guard !isRecording else { return }
        do {
            try audioRecorder.startRecording()
            isRecording = true
            settings.appState = .recording
        } catch {
            settings.appState = .error("Nie można uruchomić mikrofonu: \(error.localizedDescription)")
        }
    }

    func stopRecordingAndProcess() async {
        guard isRecording else { return }
        let samples = audioRecorder.stopRecording()
        isRecording = false

        guard !samples.isEmpty else {
            settings.appState = .idle
            return
        }

        // Transcribe
        settings.appState = .transcribing
        do {
            // Lazy load STT model if needed
            let sttLoaded = await TranscriptionEngine.shared.isModelLoaded
            if !sttLoaded {
                try await TranscriptionEngine.shared.loadModel(settings.sttModelId)
            }

            let rawText = try await TranscriptionEngine.shared.transcribe(audioSamples: samples)
            settings.lastTranscription = rawText

            guard !rawText.isEmpty else {
                settings.appState = .idle
                return
            }

            // LLM cleanup (if enabled)
            let finalText: String
            if settings.llmCleanupEnabled {
                settings.appState = .processingLLM

                // Lazy load LLM if needed
                let llmLoaded = await LLMProcessor.shared.isModelLoaded
                if !llmLoaded {
                    try await LLMProcessor.shared.loadModel(settings.llmModelId)
                }

                finalText = try await LLMProcessor.shared.cleanText(
                    rawText: rawText,
                    systemPrompt: settings.llmPrompt
                )
            } else {
                finalText = rawText
            }

            settings.lastCleanedText = finalText

            // Auto-paste
            PasteManager.shared.pasteText(finalText)
            settings.appState = .done
        } catch {
            settings.appState = .error(error.localizedDescription)
            // Reset error after 3s
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if case .error = self?.settings.appState {
                    self?.settings.appState = .idle
                }
            }
        }
    }
}
