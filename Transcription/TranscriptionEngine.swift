import Foundation
import WhisperKit

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            String(localized: "error.stt.notLoaded", defaultValue: "STT model not loaded.")
        case let .transcriptionFailed(reason):
            String(localized: "error.stt.transcriptionFailed", defaultValue: "Transcription failed:") + " " + reason
        }
    }
}

actor TranscriptionEngine {
    private static let sampleRate = 16000
    static let shared = TranscriptionEngine()

    private enum ModelSource {
        case variant(String)
        case folder(String)
    }

    private var whisperKit: WhisperKit?
    private(set) var isModelLoaded = false
    private(set) var loadedModelId: String?
    private(set) var isLoading = false
    private var loadingTask: Task<Void, Error>?
    private var loadingModelId: String?

    func loadModel(_ modelName: String = "openai_whisper-large-v3_turbo") async throws {
        try await load(.variant(modelName), modelId: modelName)
    }

    func loadModel(fromFolder folder: String) async throws {
        try await load(.folder(folder), modelId: URL(fileURLWithPath: folder).lastPathComponent)
    }

    private func load(_ source: ModelSource, modelId: String) async throws {
        // Edge case: join an in-flight load only for the same model; a different model's load
        // must not be reported as ours.
        while let existing = loadingTask {
            if loadingModelId == modelId {
                return try await existing.value
            }
            _ = try? await existing.value
        }

        let task = Task {
            let startTime = CFAbsoluteTimeGetCurrent()
            let config: WhisperKitConfig
            switch source {
            case let .variant(name):
                dlog("[STT] loading model: \(name)")
                config = WhisperKitConfig(model: name)
            case let .folder(folder):
                dlog("[STT] loading model from folder: \(folder)")
                config = WhisperKitConfig(modelFolder: folder)
            }
            try await loadWhisperKit(config)
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
        loadedModelId = modelId
    }

    private func loadWhisperKit(_ config: WhisperKitConfig) async throws {
        whisperKit = nil
        isModelLoaded = false
        loadedModelId = nil
        isLoading = true
        defer { isLoading = false }

        whisperKit = try await WhisperKit(config)
        isModelLoaded = true
    }

    func transcribe(audioSamples: [Float], language: String?, precedingText: String? = nil) async throws -> String {
        guard let whisperKit else { throw TranscriptionError.modelNotLoaded }
        let promptTokens = TranscriptionPrompt.text(language: language, precedingText: precedingText)
            .flatMap { whisperKit.tokenizer?.encode(text: " " + $0) }
        let results = try await whisperKit.transcribe(
            audioArray: audioSamples,
            decodeOptions: Self.decodingOptions(
                language: language,
                sampleCount: audioSamples.count,
                promptTokens: promptTokens
            )
        )
        let text = results.map(\.text).joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Edge case: with `language: nil` WhisperKit skips detection and decodes as English unless
    // `detectLanguage` is set. Without timestamps it also cuts audio past one 30 s window
    // mid-word, so longer audio keeps timestamps and is split at pauses instead.
    private static func decodingOptions(language: String?, sampleCount: Int, promptTokens: [Int]?) -> DecodingOptions {
        let fitsOneWindow = sampleCount <= sampleRate * 30
        return DecodingOptions(
            language: language,
            detectLanguage: language == nil,
            skipSpecialTokens: true,
            withoutTimestamps: fitsOneWindow,
            promptTokens: promptTokens,
            chunkingStrategy: fitsOneWindow ? nil : .vad
        )
    }

    func warmup() async {
        guard let whisperKit else { return }
        let startTime = CFAbsoluteTimeGetCurrent()
        dlog("[STT] warmup: transcribing 1s silent buffer")
        let oneSecondOfSilence = [Float](repeating: 0, count: Self.sampleRate)
        let options = DecodingOptions(
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        _ = try? await whisperKit.transcribe(
            audioArray: oneSecondOfSilence,
            decodeOptions: options
        )
        let warmupTime = CFAbsoluteTimeGetCurrent() - startTime
        dlog("[STT] warmup complete in \(String(format: "%.2f", warmupTime))s")
    }

    func unloadModel() {
        whisperKit = nil
        isModelLoaded = false
        loadedModelId = nil
    }
}
