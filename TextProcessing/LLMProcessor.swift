import Foundation
import CoreImage
import Hub
import Tokenizers
import MLXLLM
import MLXVLM
import MLXLMCommon
import MLX

// MARK: - Bridge: swift-transformers → MLXLMCommon

private struct HubDownloader: MLXLMCommon.Downloader {
    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        try await HubApi.shared.snapshot(
            from: id,
            revision: revision ?? "main",
            matching: patterns,
            progressHandler: progressHandler
        )
    }
}

private struct TransformersTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await AutoTokenizer.from(modelFolder: directory)
        return TokenizerBridge(upstream)
    }
}

private struct TokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        try upstream.applyChatTemplate(messages: messages, tools: tools, additionalContext: additionalContext)
    }
}

// MARK: - LLMProcessor

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
    private(set) var isVisionModel = false

    func loadModel(_ modelId: String = "mlx-community/gemma-4-e4b-it-4bit", progressHandler: (@Sendable (Progress) -> Void)? = nil) async throws {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        modelContainer = nil
        isModelLoaded = false
        isVisionModel = false

        let config = ModelConfiguration(id: modelId)

        // Auto-dispatches to VLM or LLM factory via ModelFactoryRegistry
        let container = try await loadModelContainer(
            from: HubDownloader(),
            using: TransformersTokenizerLoader(),
            configuration: config,
            progressHandler: progressHandler ?? { _ in }
        )
        modelContainer = container

        // Detect vision model at runtime
        isVisionModel = await container.perform { context in
            context.model is VLMModel
        }

        isModelLoaded = true
        currentModelId = modelId
        dlog("[LLM] loaded \(isVisionModel ? "VLM" : "LLM"): \(modelId)")
    }

    func cleanText(rawText: String, prompt: String, context: DictationContext? = nil) async throws -> String {
        guard let modelContainer else { throw LLMError.modelNotLoaded }

        let systemPrompt: String
        let userMessage: String
        var image: UserInput.Image?

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
            if let screenshot = context.screenshot, isVisionModel {
                image = .ciImage(CIImage(cgImage: screenshot))
                dlog("[LLM] passing screenshot to vision model")
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

        var result = try await session.respond(to: userMessage, image: image)

        // Strip thinking blocks (Qwen3, Gemma)
        if let thinkEnd = result.range(of: "</think>") {
            result = String(result[thinkEnd.upperBound...])
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func warmup() async {
        guard let modelContainer else { return }
        dlog("[LLM] warmup: generating dummy completion (vision=\(isVisionModel))")
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
        isVisionModel = false
        currentModelId = nil
    }
}
