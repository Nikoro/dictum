import Foundation
import WhisperKit

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return String(localized: "error.stt.notLoaded", defaultValue: "STT model not loaded.")
        case .transcriptionFailed(let reason):
            return String(localized: "error.stt.transcriptionFailed", defaultValue: "Transcription failed:") + " " + reason
        }
    }
}

actor TranscriptionEngine {
    static let shared = TranscriptionEngine()

    private var whisperKit: WhisperKit?
    private(set) var isModelLoaded = false
    private(set) var isLoading = false
    private(set) var currentModelId: String?
    private var loadingTask: Task<Void, Error>?

    func loadModel(_ modelName: String = "openai_whisper-large-v3_turbo") async throws {
        if let existingTask = loadingTask { return try await existingTask.value }

        let config = WhisperKitConfig(
            model: modelName,
            verbose: true,
            logLevel: .debug
        )
        dlog("[STT] loading model: \(modelName)")
        try await loadWhisperKit(config, modelId: modelName)
        dlog("[STT] model loaded successfully")
    }

    func loadModel(fromFolder folder: String) async throws {
        if let existingTask = loadingTask { return try await existingTask.value }

        let startTime = CFAbsoluteTimeGetCurrent()
        dlog("[STT] loading model from folder: \(folder)")
        let config = WhisperKitConfig(
            modelFolder: folder,
            verbose: true,
            logLevel: .debug
        )
        let modelId = URL(fileURLWithPath: folder).lastPathComponent
        try await loadWhisperKit(config, modelId: modelId)
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        dlog("[STT] model loaded successfully in \(String(format: "%.2f", loadTime))s")
    }

    private func loadWhisperKit(_ config: WhisperKitConfig, modelId: String) async throws {
        let task = Task {
            whisperKit = nil
            isModelLoaded = false
            isLoading = true
            defer { isLoading = false; loadingTask = nil }

            whisperKit = try await WhisperKit(config)
            isModelLoaded = true
            currentModelId = modelId
        }
        loadingTask = task
        try await task.value
    }

    func transcribe(audioSamples: [Float], language: String? = nil) async throws -> String {
        guard let whisperKit else { throw TranscriptionError.modelNotLoaded }

        let options = DecodingOptions(
            language: language,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )

        let results = try await whisperKit.transcribe(
            audioArray: audioSamples,
            decodeOptions: options
        )

        let text = results.map(\.text).joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func warmup() async {
        guard let whisperKit else { return }
        let startTime = CFAbsoluteTimeGetCurrent()
        dlog("[STT] warmup: transcribing 1s silent buffer")
        let silentSamples = [Float](repeating: 0, count: 16000) // 1s at 16kHz
        let options = DecodingOptions(
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        _ = try? await whisperKit.transcribe(
            audioArray: silentSamples,
            decodeOptions: options
        )
        let warmupTime = CFAbsoluteTimeGetCurrent() - startTime
        dlog("[STT] warmup complete in \(String(format: "%.2f", warmupTime))s")
    }

    func unloadModel() {
        whisperKit = nil
        isModelLoaded = false
        currentModelId = nil
    }
}
