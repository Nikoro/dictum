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

    private enum ModelSource {
        case variant(String)
        case folder(String)
    }

    private var whisperKit: WhisperKit?
    private(set) var isModelLoaded = false
    private(set) var isLoading = false
    private(set) var currentModelId: String?
    private var loadingTask: Task<Void, Error>?
    private var loadingModelId: String?

    func loadModel(_ modelName: String = "openai_whisper-large-v3_turbo") async throws {
        try await load(.variant(modelName), modelId: modelName)
    }

    func loadModel(fromFolder folder: String) async throws {
        try await load(.folder(folder), modelId: URL(fileURLWithPath: folder).lastPathComponent)
    }

    private func load(_ source: ModelSource, modelId: String) async throws {
        // Join an in-flight load only when it is for the same model. A load for a *different*
        // model must not be silently reported as success — wait it out, then load ours.
        while let existing = loadingTask {
            if loadingModelId == modelId { return try await existing.value }
            _ = try? await existing.value
        }

        let task = Task {
            let startTime = CFAbsoluteTimeGetCurrent()
            let config: WhisperKitConfig
            switch source {
            case .variant(let name):
                dlog("[STT] loading model: \(name)")
                config = WhisperKitConfig(model: name)
            case .folder(let folder):
                dlog("[STT] loading model from folder: \(folder)")
                config = WhisperKitConfig(modelFolder: folder)
            }
            try await loadWhisperKit(config, modelId: modelId)
            let loadTime = CFAbsoluteTimeGetCurrent() - startTime
            dlog("[STT] model loaded successfully in \(String(format: "%.2f", loadTime))s")
        }
        loadingTask = task
        loadingModelId = modelId
        defer {
            loadingTask = nil
            loadingModelId = nil
        }
        try await task.value
    }

    private func loadWhisperKit(_ config: WhisperKitConfig, modelId: String) async throws {
        whisperKit = nil
        isModelLoaded = false
        isLoading = true
        defer { isLoading = false }

        whisperKit = try await WhisperKit(config)
        isModelLoaded = true
        currentModelId = modelId
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
