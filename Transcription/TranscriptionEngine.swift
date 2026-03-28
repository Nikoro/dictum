import Foundation
import WhisperKit

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model STT nie jest załadowany."
        case .transcriptionFailed(let reason):
            return "Transkrypcja nie powiodła się: \(reason)"
        }
    }
}

actor TranscriptionEngine {
    static let shared = TranscriptionEngine()

    private var whisperKit: WhisperKit?
    private(set) var isModelLoaded = false
    private(set) var isLoading = false
    private(set) var currentModelId: String?

    func loadModel(_ modelName: String = "openai_whisper-large-v3_turbo") async throws {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Unload previous model
        whisperKit = nil
        isModelLoaded = false

        dlog("[STT] loading model: \(modelName)")
        let config = WhisperKitConfig(
            model: modelName,
            verbose: true,
            logLevel: .debug
        )
        whisperKit = try await WhisperKit(config)
        isModelLoaded = true
        currentModelId = modelName
        dlog("[STT] model loaded successfully")
    }

    func loadModel(fromFolder folder: String) async throws {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        whisperKit = nil
        isModelLoaded = false

        dlog("[STT] loading model from folder: \(folder)")
        let config = WhisperKitConfig(
            modelFolder: folder,
            verbose: true,
            logLevel: .debug
        )
        whisperKit = try await WhisperKit(config)
        isModelLoaded = true
        currentModelId = URL(fileURLWithPath: folder).lastPathComponent
        dlog("[STT] model loaded successfully")
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        guard let whisperKit else { throw TranscriptionError.modelNotLoaded }

        let options = DecodingOptions(
            language: "pl",
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

    func unloadModel() {
        whisperKit = nil
        isModelLoaded = false
        currentModelId = nil
    }
}
