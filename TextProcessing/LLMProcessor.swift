import CoreImage
import Foundation
import Hub
import MLX
import MLXLLM
import MLXLMCommon
import MLXVLM
import Tokenizers

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

    var bosToken: String? {
        upstream.bosToken
    }

    var eosToken: String? {
        upstream.eosToken
    }

    var unknownToken: String? {
        upstream.unknownToken
    }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        try upstream.applyChatTemplate(messages: messages, tools: tools, additionalContext: additionalContext)
    }
}

enum LLMError: LocalizedError {
    case modelNotLoaded
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            String(localized: "error.llm.notLoaded", defaultValue: "LLM model not loaded.")
        case let .generationFailed(reason):
            String(localized: "error.llm.generationFailed", defaultValue: "Text generation failed:") + " " + reason
        }
    }
}

actor LLMProcessor {
    static let shared = LLMProcessor()

    private var modelContainer: ModelContainer?
    private(set) var isModelLoaded = false
    private(set) var isLoading = false
    private(set) var isVisionModel = false
    private var loadingTask: Task<Void, Error>?
    private var loadingModelId: String?

    // Edge case: concurrent calls for the same model share one load, so only the first caller's
    // progressHandler reports.
    func loadModel(
        _ modelId: String = "mlx-community/gemma-4-e4b-it-4bit",
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws {
        // Edge case: a call for another model must wait and load its own, never return early;
        // callers treat a clean return as "this model is ready".
        while let existing = loadingTask {
            if loadingModelId == modelId {
                return try await existing.value
            }
            _ = try? await existing.value
        }

        let task = Task {
            try await performLoad(modelId, progressHandler: progressHandler)
        }
        loadingTask = task
        loadingModelId = modelId
        defer {
            loadingTask = nil
            loadingModelId = nil
        }
        try await task.value
    }

    private func performLoad(_ modelId: String, progressHandler: (@Sendable (Progress) -> Void)?) async throws {
        isLoading = true
        defer { isLoading = false }

        modelContainer = nil
        isModelLoaded = false
        isVisionModel = false

        let config = ModelConfiguration(id: modelId)

        let container = try await loadModelContainer(
            from: HubDownloader(),
            using: TransformersTokenizerLoader(),
            configuration: config,
            progressHandler: progressHandler ?? { _ in }
        )
        modelContainer = container

        isVisionModel = await container.perform { context in
            context.model is VLMModel
        }

        isModelLoaded = true
        dlog("[LLM] loaded \(isVisionModel ? "VLM" : "LLM"): \(modelId)")
    }

    func cleanText(rawText: String, prompt: String, context: DictationContext? = nil) async throws -> String {
        guard let modelContainer else { throw LLMError.modelNotLoaded }

        let userMessage = context.map { Self.userMessage(rawText: rawText, context: $0) } ?? rawText
        var images: [UserInput.Image] = []
        if let context, isVisionModel {
            images = Self.visionImages(from: context)
        }

        let session = ChatSession(
            modelContainer,
            instructions: prompt,
            generateParameters: GenerateParameters(
                maxTokens: 2048,
                temperature: 0.7,
                topP: 0.9
            )
        )

        let result = try await session.respond(to: userMessage, images: images, videos: [], audios: [])
        return Self.removingReasoningBlock(from: result).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func userMessage(rawText: String, context: DictationContext) -> String {
        var parts: [String] = []
        if let appName = context.appName {
            parts.append("App: \(appName)")
        }
        if let selectedText = context.selectedText, !selectedText.isEmpty {
            parts.append("Selected text:\n\(selectedText)")
        }
        if let clipboardText = context.clipboardText, !clipboardText.isEmpty {
            parts.append("Clipboard:\n\(clipboardText)")
        }
        if let ocrText = context.ocrText, !ocrText.isEmpty {
            parts.append("Screen text (OCR):\n\(ocrText)")
            dlog("[LLM] attached OCR \(ocrText.count) chars")
        }
        parts.append("Spoken words: \(rawText)")
        return parts.joined(separator: "\n\n")
    }

    private static func visionImages(from context: DictationContext) -> [UserInput.Image] {
        if let screenshot = context.screenshot {
            dlog("[LLM] passing screenshot to vision model")
            return [.ciImage(CIImage(cgImage: screenshot))]
        }
        if let clipboardImage = context.clipboardImage {
            dlog("[LLM] passing clipboard image to vision model")
            return [.ciImage(CIImage(cgImage: clipboardImage))]
        }
        return []
    }

    private static func removingReasoningBlock(from result: String) -> String {
        guard let thinkEnd = result.range(of: "</think>") else { return result }
        return String(result[thinkEnd.upperBound...])
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
    }
}
