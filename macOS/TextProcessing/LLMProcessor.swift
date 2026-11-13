import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXVLM

enum LLMError: LocalizedError {
    case modelNotLoaded
    case invalidModelId(String)
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            String(localized: "error.llm.notLoaded", defaultValue: "LLM model not loaded.")
        case let .invalidModelId(modelId):
            String(localized: "error.llm.invalidModelId", defaultValue: "Invalid model:") + " " + modelId
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
    private let prefixCache = PromptPrefixCache()
    private var drafter: DrafterBox?

    func loadModel(
        _ modelId: String = "mlx-community/gemma-4-e4b-it-4bit",
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws {
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
        drafter = nil
        prefixCache.reset()
        isModelLoaded = false
        isVisionModel = false

        let config = ModelConfiguration(id: modelId)

        let container = try await loadModelContainer(
            from: OfflineFirstHubDownloader(),
            using: TransformersTokenizerLoader(),
            configuration: config,
            progressHandler: progressHandler ?? { _ in }
        )
        modelContainer = container
        Memory.cacheLimit = Self.gpuCacheLimitBytes

        isVisionModel = await container.perform { context in
            context.model is VLMModel
        }

        isModelLoaded = true
        dlog("[LLM] loaded \(isVisionModel ? "VLM" : "LLM"): \(modelId)")
        if let drafterId = LLMPrompting.drafterId(for: modelId) {
            do {
                try await loadDrafter(drafterId)
            } catch {
                dlog("[LLM] MTP drafter unavailable, generating without it: \(error)")
            }
        }
    }

    func loadDrafter(_ drafterId: String) async throws {
        drafter = try await DrafterBox.load(drafterId)
        dlog("[LLM] MTP drafter loaded: \(drafterId)")
    }

    #if DEBUG
    var debugModelContainer: ModelContainer? {
        modelContainer
    }
    #endif

    func cleanText(rawText: String, prompt: String, context: DictationContext? = nil) async throws -> String {
        guard let modelContainer else { throw LLMError.modelNotLoaded }
        let userMessage = LLMPrompting.userMessage(rawText: rawText, context: context)
        let parameters = GenerateParameters(maxTokens: LLMPrompting.outputTokenBudget(for: rawText), temperature: 0)
        let imageContext = isVisionModel ? context.flatMap { LLMPrompting.hasImage($0) ? $0 : nil } : nil
        let result = if let imageContext {
            try await generateWithImages(
                modelContainer,
                prompt: prompt,
                userMessage: userMessage,
                imageContext: imageContext,
                parameters: parameters
            )
        } else {
            try await generateFromCachedPrefix(modelContainer, prompt: prompt, userMessage: userMessage, parameters: parameters)
        }
        return LLMPrompting.removingReasoningBlock(from: result).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generateWithImages(
        _ modelContainer: ModelContainer,
        prompt: String,
        userMessage: String,
        imageContext: DictationContext,
        parameters: GenerateParameters
    ) async throws -> String {
        let images = LLMPrompting.visionImages(from: imageContext)
        let session = ChatSession(
            modelContainer,
            instructions: prompt,
            generateParameters: parameters,
            additionalContext: LLMPrompting.disableThinking
        )
        return try await session.respond(to: userMessage, images: images, videos: [], audios: [])
    }

    private func generateFromCachedPrefix(
        _ modelContainer: ModelContainer,
        prompt: String,
        userMessage: String,
        parameters: GenerateParameters
    ) async throws -> String {
        let generator = CachedPrefixGenerator(prefixCache: prefixCache, drafter: drafter)
        return try await modelContainer.perform { context in
            try await generator.generate(context: context, prompt: prompt, userMessage: userMessage, parameters: parameters)
        }
    }

    private static let gpuCacheLimitBytes = 64 * 1024 * 1024

    func warmup(systemPrompt: String) async {
        guard let modelContainer else { return }
        dlog("[LLM] warmup with the real system prompt (vision=\(isVisionModel))")
        _ = try? await generateFromCachedPrefix(
            modelContainer,
            prompt: systemPrompt,
            userMessage: LLMPrompting.userMessage(
                rawText: "Dzień dobry, chciałbym umówić spotkanie na jutro rano.",
                context: nil
            ),
            parameters: GenerateParameters(maxTokens: 8, temperature: 0)
        )
        dlog("[LLM] warmup complete")
    }

    func unloadModel() {
        Stream.gpu.synchronize()
        Memory.cacheLimit = 0
        modelContainer = nil
        drafter = nil
        prefixCache.reset()
        isModelLoaded = false
        isVisionModel = false
        Stream.gpu.synchronize()
        Memory.clearCache()
    }
}
