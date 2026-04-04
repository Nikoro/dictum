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

    func cleanText(rawText: String, prompt: String, context: DictationContext? = nil) async throws -> String {
        guard let modelContainer else { throw LLMError.modelNotLoaded }

        let systemPrompt: String
        let userMessage: String

        if let context {
            // Smart context mode: unified prompt as system, structured user message
            systemPrompt = prompt

            var parts: [String] = []
            if let appName = context.appName {
                parts.append("App: \(appName)")
            }
            if let selectedText = context.selectedText, !selectedText.isEmpty {
                parts.append("Selected text:\n\(selectedText)")
            }
            if context.screenshot != nil {
                // TODO: When mlx-swift-lm 3.x ships with MLXVLM, pass screenshot as image input
                // via ChatSession.respond(to:images: [.ciImage(CIImage(cgImage: screenshot))])
                parts.append("[Screenshot captured — vision model not yet available]")
            }
            parts.append("Spoken words: \(rawText)")
            userMessage = parts.joined(separator: "\n\n")
        } else {
            // Fallback: no context
            systemPrompt = prompt
            userMessage = rawText
        }

        let session = ChatSession(
            modelContainer,
            instructions: systemPrompt,
            generateParameters: GenerateParameters(
                maxTokens: 2048,
                temperature: 0.7,
                topP: 0.9
            )
        )

        var result = try await session.respond(to: userMessage)

        // Strip thinking blocks (Qwen3, Gemma)
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
