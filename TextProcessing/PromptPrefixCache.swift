import Foundation
import MLX
import MLXLMCommon
import MLXVLM

// Edge case: only touched inside ModelContainer.perform, which serializes access, so the
// non-Sendable KV arrays are never shared across threads.
final class PromptPrefixCache: @unchecked Sendable {
    private var prompt: String?
    private var tokens: [Int] = []
    private var cache: [KVCache] = []

    func reset() {
        prompt = nil
        tokens = []
        cache = []
    }

    // Edge case: Gemma 4's sliding-window cache cannot be trimmed back once used, so the prefilled
    // prefix is kept pristine and every generation continues from a copy of it.
    func copy(
        for systemPrompt: String,
        context: ModelContext,
        parameters: GenerateParameters,
        additionalContext: [String: any Sendable]
    ) async throws -> (tokens: [Int], cache: [KVCache]) {
        if prompt != systemPrompt {
            try await prefill(systemPrompt, context: context, parameters: parameters, additionalContext: additionalContext)
        }
        return (tokens, cache.map { $0.copy() })
    }

    private func prefill(
        _ systemPrompt: String,
        context: ModelContext,
        parameters: GenerateParameters,
        additionalContext: [String: any Sendable]
    ) async throws {
        let first = try await Self.tokens(
            system: systemPrompt,
            user: "\u{1}",
            context: context,
            additionalContext: additionalContext
        )
        let second = try await Self.tokens(
            system: systemPrompt,
            user: "\u{2}",
            context: context,
            additionalContext: additionalContext
        )
        let shared = Array(zip(first, second).prefix { $0 == $1 }.map(\.0))
        let freshCache = try context.model.newCache(parameters: parameters)
        _ = try TokenIterator(
            input: LMInput(tokens: MLXArray(shared.map(Int32.init))),
            model: context.model,
            cache: freshCache,
            parameters: parameters
        )
        eval(freshCache.flatMap(\.state))
        prompt = systemPrompt
        tokens = shared
        cache = freshCache
        dlog("[LLM] prefilled \(shared.count) system prompt tokens")
    }

    static func tokens(
        system: String,
        user: String,
        context: ModelContext,
        additionalContext: [String: any Sendable]
    ) async throws -> [Int] {
        let input = try await context.processor.prepare(input: UserInput(
            chat: [.system(system), .user(user)],
            additionalContext: additionalContext
        ))
        return input.text.tokens.asArray(Int.self)
    }
}

// Edge case: MTP drafters hold no target-derived state and are documented as safe to share
// across iterators; the box only carries the non-Sendable model into ModelContainer.perform.
final class DrafterBox: @unchecked Sendable {
    let model: any MTPDrafterModel

    private init(_ model: any MTPDrafterModel) {
        self.model = model
    }

    static func load(_ drafterId: String) async throws -> DrafterBox {
        let directory = try await OfflineFirstHubDownloader().download(
            id: drafterId,
            revision: nil,
            matching: ["*.safetensors", "*.json"],
            useLatest: false
        ) { _ in }
        let configData = try Data(contentsOf: directory.appendingPathComponent("config.json"))
        let configuration = try JSONDecoder().decode(Gemma4AssistantConfiguration.self, from: configData)
        let base = try JSONDecoder().decode(BaseConfiguration.self, from: configData)
        let model = Gemma4AssistantDraftModel(configuration)
        try await loadWeights(
            modelDirectory: directory,
            model: model,
            quantization: base.quantization,
            perLayerQuantization: base.perLayerQuantization
        )
        return DrafterBox(model)
    }
}

struct CachedPrefixGenerator: Sendable {
    let prefixCache: PromptPrefixCache
    let drafter: DrafterBox?

    func generate(
        context: ModelContext,
        prompt: String,
        userMessage: String,
        parameters: GenerateParameters
    ) async throws -> String {
        let (input, cache) = try await inputContinuingPrefix(
            context: context,
            prompt: prompt,
            userMessage: userMessage,
            parameters: parameters
        )
        let stream = if let drafter {
            try MLXLMCommon.generate(
                input: input,
                cache: cache,
                parameters: parameters,
                context: context,
                mtpDrafter: drafter.model
            )
        } else {
            try MLXLMCommon.generate(input: input, cache: cache, parameters: parameters, context: context)
        }
        var text = ""
        for await event in stream {
            if case let .chunk(chunk) = event {
                text += chunk
            }
        }
        return text
    }

    private func inputContinuingPrefix(
        context: ModelContext,
        prompt: String,
        userMessage: String,
        parameters: GenerateParameters
    ) async throws -> (LMInput, [KVCache]?) {
        let thinking = LLMPrompting.disableThinking
        let fullTokens = try await PromptPrefixCache.tokens(
            system: prompt,
            user: userMessage,
            context: context,
            additionalContext: thinking
        )
        let prefix = try await prefixCache.copy(
            for: prompt,
            context: context,
            parameters: parameters,
            additionalContext: thinking
        )
        guard fullTokens.starts(with: prefix.tokens), fullTokens.count > prefix.tokens.count else {
            return (LMInput(tokens: MLXArray(fullTokens.map(Int32.init))), nil)
        }
        let remaining = fullTokens[prefix.tokens.count...]
        return (LMInput(tokens: MLXArray(remaining.map(Int32.init))), prefix.cache)
    }
}
