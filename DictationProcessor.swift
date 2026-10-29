import AppKit

@MainActor
struct DictationProcessor {
    let targetAppAtRecordingStart: NSRunningApplication?
    let selectedTextAtHotkeyPress: String?
    let isAborted: @MainActor () -> Bool

    private let settings = AppSettings.shared
    private let runtimeState = AppRuntimeState.shared
    private let modelWarmup = ModelWarmupCoordinator.shared

    func transcribe(samples: [Float]) async throws -> String {
        runtimeState.appState = .transcribing
        try await modelWarmup.loadSTTModelIfNeeded()
        guard !isAborted() else { return "" }
        let sttLanguage = settings.resolveSTTLanguage(for: targetAppAtRecordingStart?.bundleIdentifier)
        dlog("[Dictum] transcribing \(samples.count) samples, language: \(sttLanguage ?? "auto")...")
        let rawText = try await TranscriptionEngine.shared.transcribe(audioSamples: samples, language: sttLanguage)
        guard !isAborted() else { return "" }
        dlog("[Dictum] transcription complete, \(rawText.count) chars")
        runtimeState.lastTranscription = rawText
        return rawText
    }

    // Edge case: the context is returned even without LLM cleanup, because a selection means
    // "copy the result" rather than paste over it.
    func finalize(_ rawText: String) async -> (text: String, context: DictationContext?) {
        let context = await gatherContext()
        guard settings.llmCleanupEnabled else {
            dlog("[Dictum] LLM cleanup disabled, returning raw transcription")
            return (rawText, context)
        }
        return await (cleanUpOrKeepRaw(rawText, context: context), context)
    }

    private func gatherContext() async -> DictationContext? {
        let options = ContextOptions(settings: settings)
        guard settings.smartContextEnabled, !options.isEmpty else {
            dlog("[Dictum] smart context disabled, skipping")
            return nil
        }
        let target = targetAppAtRecordingStart.map {
            TargetApp(pid: $0.processIdentifier, name: $0.localizedName, bundleId: $0.bundleIdentifier)
        }
        let context = await ContextGatherer.gather(
            selectedText: selectedTextAtHotkeyPress,
            targetApp: target,
            options: options,
            ocrLanguages: settings.resolveOCRLanguages(for: target?.bundleId)
        )
        dlog("[Dictum] context: \(context.sourcesPresentWithoutContents)")
        return context
    }

    private func cleanUpOrKeepRaw(_ rawText: String, context: DictationContext?) async -> String {
        let bundleId = targetAppAtRecordingStart?.bundleIdentifier
        let prompt = settings.resolvePrompt(for: bundleId)
        runtimeState.appState = .processingLLM
        do {
            try await modelWarmup.loadLLMModelIfNeeded()
            dlog("[Dictum] LLM prompt for \(bundleId ?? "general")")
            dlog("[Dictum] LLM input: \(rawText.count) chars, context: \(context?.selectedText != nil ? "yes" : "none")")
            let cleanedText = try await LLMProcessor.shared.cleanText(rawText: rawText, prompt: prompt, context: context)
            dlog("[Dictum] LLM output: \(cleanedText.count) chars")
            return cleanedText
        } catch {
            dlog("[Dictum] LLM cleanup failed, using raw text: \(error)")
            return rawText
        }
    }
}
