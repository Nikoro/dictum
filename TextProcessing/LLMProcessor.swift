import Foundation
import MLXLLM
import MLXLMCommon
import MLX

enum LLMError: LocalizedError {
    case modelNotLoaded
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model LLM nie jest załadowany."
        case .generationFailed(let reason):
            return "Generowanie tekstu nie powiodło się: \(reason)"
        }
    }
}

actor LLMProcessor {
    static let shared = LLMProcessor()

    private var modelContainer: ModelContainer?
    private(set) var isModelLoaded = false
    private(set) var isLoading = false
    private(set) var currentModelId: String?

    func loadModel(_ modelId: String = "mlx-community/Qwen3-4B-Instruct-4bit") async throws {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        modelContainer = nil
        isModelLoaded = false

        let config = ModelConfiguration(id: modelId)
        modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: config
        )
        isModelLoaded = true
        currentModelId = modelId
    }

    func cleanText(rawText: String, systemPrompt: String) async throws -> String {
        guard let modelContainer else { throw LLMError.modelNotLoaded }

        let session = ChatSession(
            modelContainer,
            instructions: systemPrompt,
            generateParameters: GenerateParameters(
                maxTokens: 2048,
                temperature: 0.1,
                topP: 0.9
            )
        )

        let result = try await session.respond(to: rawText)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func unloadModel() {
        modelContainer = nil
        isModelLoaded = false
        currentModelId = nil
    }
}
