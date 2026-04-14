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
            return String(localized: "error.llm.notLoaded", defaultValue: "LLM model not loaded.")
        case .generationFailed(let reason):
            return String(localized: "error.llm.generationFailed", defaultValue: "Text generation failed:") + " " + reason
        }
    }
}

actor LLMProcessor {
    static let shared = LLMProcessor()

    private var modelContainer: ModelContainer?
    private(set) var isModelLoaded = false
    private(set) var isLoading = false
    private(set) var currentModelId: String?

    func loadModel(_ modelId: String = "mlx-community/gemma-4-e2b-it-4bit", progressHandler: (@Sendable (Progress) -> Void)? = nil) async throws {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        modelContainer = nil
        isModelLoaded = false

        let config = ModelConfiguration(id: modelId)
        modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: config,
            progressHandler: progressHandler ?? { _ in }
        )
        isModelLoaded = true
        currentModelId = modelId
    }

    func cleanText(rawText: String, prompt: String, context: String? = nil) async throws -> String {
        guard let modelContainer else { throw LLMError.modelNotLoaded }

        let systemPrompt: String?
        let userMessage: String

        if let context {
            // Context mode: user selected text and dictated an instruction.
            // Ignore the default cleanup prompt — use a dedicated context prompt.
            if prompt.contains("{{context}}") {
                // Custom prompt with {{context}} and {{text}} placeholders
                let resolved = prompt
                    .replacingOccurrences(of: "{{context}}", with: context)
                    .replacingOccurrences(of: "{{text}}", with: rawText)
                systemPrompt = nil
                userMessage = resolved
            } else {
                systemPrompt = "Execute the user's instruction based on the provided context. Return ONLY the result, no commentary."
                userMessage = "Context:\n\(context)\n\nInstruction: \(rawText)"
            }
        } else {
            // Normal mode: standard cleanup/prompt
            // `{{text}}` means the full prompt becomes a user message; otherwise treat the prompt
            // as system instructions and send only the raw transcription as user input.
            let hasPlaceholder = prompt.contains("{{text}}")
            systemPrompt = hasPlaceholder ? nil : prompt
            userMessage = hasPlaceholder ? prompt.replacingOccurrences(of: "{{text}}", with: rawText) : rawText
        }

        let session = ChatSession(
            modelContainer,
            instructions: systemPrompt ?? "",
            generateParameters: GenerateParameters(
                maxTokens: 2048,
                temperature: 0.7,
                topP: 0.9
            )
        )

        var result = try await session.respond(to: userMessage)

        // Some MLX community models emit hidden reasoning blocks; strip them before returning text.
        if let thinkEnd = result.range(of: "</think>") {
            result = String(result[thinkEnd.upperBound...])
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func warmup() async {
        guard let modelContainer else { return }
        dlog("[LLM] warmup: generating dummy completion")
        let session = ChatSession(
            modelContainer,
            instructions: "",
            generateParameters: GenerateParameters(
                maxTokens: 2,
                temperature: 0.0,
                topP: 1.0
            )
        )
        _ = try? await session.respond(to: "Hi")
        dlog("[LLM] warmup complete")
    }

    func unloadModel() {
        modelContainer = nil
        isModelLoaded = false
        currentModelId = nil
    }
}
