extension AppSettings {
    func resolvePrompt(for bundleId: String?) -> String {
        let base = unifiedSystemPrompt.isEmpty ? DefaultPrompts.unified : unifiedSystemPrompt

        if let bundleId,
           let appPrompt = appPrompts.first(where: { $0.bundleId == bundleId && $0.enabled }),
           !appPrompt.prompt.isEmpty
        {
            return base + "\n\nAdditional instructions for this app:\n" + appPrompt.prompt
        }

        if llmGeneralPromptEnabled, !llmPrompt.isEmpty {
            return base + "\n\nAdditional instructions:\n" + llmPrompt
        }

        return base
    }

    func resolveSTTLanguage(for bundleId: String?) -> String? {
        effectiveLanguage(for: bundleId).whisperCodeOrNilForAutoDetect
    }

    func resolveOCRLanguages(for bundleId: String?) -> [String] {
        effectiveLanguage(for: bundleId).ocrLanguages
    }

    private func effectiveLanguage(for bundleId: String?) -> STTLanguage {
        guard let bundleId,
              let appLanguage = appSTTLanguages.first(where: { $0.bundleId == bundleId && $0.enabled })
        else {
            return sttLanguage
        }
        return appLanguage.language
    }
}
