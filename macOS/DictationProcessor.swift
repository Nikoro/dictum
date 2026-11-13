import AppKit

@MainActor
final class DictationProcessor {
    private let targetAppAtRecordingStart: NSRunningApplication?
    private let selectedTextAtHotkeyPress: String?
    private let isAborted: @MainActor () -> Bool
    private let settings = AppSettings.shared
    private let runtimeState = AppRuntimeState.shared
    private let modelWarmup = ModelWarmupCoordinator.shared
    private let liveTranscriber: LiveChunkTranscriber
    private static let llmTimeLimit: Duration = .seconds(30)

    private static func isPlausibleCleanup(_ cleaned: String, of raw: String, hasContext: Bool) -> Bool {
        guard !cleaned.isEmpty else { return false }
        return hasContext || Double(cleaned.count) >= Double(raw.count) * 0.3
    }

    private var contextTask: Task<DictationContext?, Never>?

    init(
        targetAppAtRecordingStart: NSRunningApplication?,
        selectedTextAtHotkeyPress: String?,
        audioRecorder: AudioRecorder,
        isAborted: @escaping @MainActor () -> Bool
    ) {
        self.targetAppAtRecordingStart = targetAppAtRecordingStart
        self.selectedTextAtHotkeyPress = selectedTextAtHotkeyPress
        self.isAborted = isAborted
        let language = AppSettings.shared.resolveSTTLanguage(for: targetAppAtRecordingStart?.bundleIdentifier)
        liveTranscriber = LiveChunkTranscriber(audioSource: audioRecorder, language: language, isAborted: isAborted)
    }

    func recordingStarted() {
        liveTranscriber.start()
        contextTask = Task {
            let signpost = DictumSignposts.pipeline.beginInterval("ContextCapture")
            defer { DictumSignposts.pipeline.endInterval("ContextCapture", signpost) }
            return await gatherContext()
        }
    }

    func cancel() {
        liveTranscriber.cancel()
        contextTask?.cancel()
    }

    func transcribe(allSamples: [Float]) async throws -> String {
        runtimeState.appState = .transcribing
        try await modelWarmup.loadSTTModelIfNeeded()
        guard !isAborted() else { return "" }
        dlog("[Dictum] transcribing \(allSamples.count) samples")
        let signpost = DictumSignposts.pipeline.beginInterval("Transcription")
        defer { DictumSignposts.pipeline.endInterval("Transcription", signpost) }
        let transcript = try await liveTranscriber.finish(allSamples: allSamples)
        let rawText = WordReplacementStore.shared.apply(to: transcript)
        guard !isAborted() else { return "" }
        dlog("[Dictum] transcription complete, \(rawText.count) chars")
        runtimeState.lastTranscription = rawText
        return rawText
    }

    func finalize(_ rawText: String) async -> (text: String, context: DictationContext?) {
        let context = await contextTask?.value
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
        let signpost = DictumSignposts.pipeline.beginInterval("LLMCleanup")
        defer { DictumSignposts.pipeline.endInterval("LLMCleanup", signpost) }
        do {
            try await modelWarmup.loadLLMModelIfNeeded()
            dlog("[Dictum] LLM prompt for \(bundleId ?? "general")")
            dlog("[Dictum] LLM input: \(rawText.count) chars, context: \(context?.selectedText != nil ? "yes" : "none")")
            let cleanedText = try await withTimeLimit(Self.llmTimeLimit) {
                try await LLMProcessor.shared.cleanText(rawText: rawText, prompt: prompt, context: context)
            }
            dlog("[Dictum] LLM output: \(cleanedText.count) chars")
            return Self.isPlausibleCleanup(cleanedText, of: rawText, hasContext: context != nil) ? cleanedText : rawText
        } catch {
            dlog("[Dictum] LLM cleanup failed, using raw text: \(error)")
            return rawText
        }
    }
}
