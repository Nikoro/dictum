import Foundation

// Edge case: the first inference compiles Metal shaders and takes seconds, so a dummy one runs
// right after loading instead of during the user's first dictation.
@MainActor
final class ModelWarmupCoordinator {
    static let shared = ModelWarmupCoordinator()

    private let settings = AppSettings.shared
    private let whisperModelStore = WhisperModelStore.shared
    private(set) var isWarmedUp = false
    private var warmupTask: Task<Void, Never>?
    private var idleUnloadTask: Task<Void, Never>?

    var isWarmingUp: Bool {
        !isWarmedUp && warmupTask != nil
    }

    var activeSpeechEngine: SpeechEngine {
        settings.sttEngine == .parakeet && settings.parakeetVariant.isDownloaded ? .parakeet : .whisper
    }

    var hasSpeechModel: Bool {
        activeSpeechEngine == .parakeet || whisperModelStore.downloadedModelIds.contains(settings.sttModelId)
    }

    func switchSpeechModel() {
        Task {
            if activeSpeechEngine == .parakeet {
                await TranscriptionEngine.shared.unloadModel()
            } else {
                await ParakeetEngine.shared.unloadModel()
            }
            preloadModels()
        }
    }

    func preloadModels() {
        guard hasSpeechModel else { return }
        Task {
            await whisperModelStore.migrateLegacyModelsIfNeeded()
            do {
                try await loadSTTModelIfNeeded()
                if settings.llmCleanupEnabled {
                    try await loadLLMModelIfNeeded()
                }
                warmUpModels()
            } catch {
                dlog("[Dictum] preload failed: \(error)")
            }
        }
    }

    func warmUpModels() {
        warmupTask?.cancel()
        isWarmedUp = false
        warmupTask = Task {
            dlog("[Dictum] warmup started")
            await withTaskGroup(of: Void.self) { group in
                if await TranscriptionEngine.shared.isModelLoaded {
                    group.addTask { await TranscriptionEngine.shared.warmup() }
                }
                if await LLMProcessor.shared.isModelLoaded {
                    let systemPrompt = settings.resolvePrompt(for: nil)
                    group.addTask { await LLMProcessor.shared.warmup(systemPrompt: systemPrompt) }
                }
            }
            guard !Task.isCancelled else { return }
            isWarmedUp = true
            dlog("[Dictum] warmup complete")
            scheduleIdleUnload()
        }
    }

    // Edge case: loading starts with the recording, so a model unloaded while idle is usually
    // back before the user stops talking.
    func prepareForDictation() {
        idleUnloadTask?.cancel()
        Task {
            try? await loadSTTModelIfNeeded()
            if settings.llmCleanupEnabled {
                try? await loadLLMModelIfNeeded()
            }
        }
    }

    func scheduleIdleUnload() {
        idleUnloadTask?.cancel()
        let minutes = settings.modelIdleUnloadMinutes
        guard minutes > 0 else { return }
        idleUnloadTask = Task {
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled else { return }
            dlog("[Dictum] idle for \(minutes) min, unloading models")
            isWarmedUp = false
            await TranscriptionEngine.shared.unloadModel()
            await ParakeetEngine.shared.unloadModel()
            await LLMProcessor.shared.unloadModel()
        }
    }

    func waitForWarmup() async {
        await warmupTask?.value
    }

    func loadSTTModelIfNeeded() async throws {
        if activeSpeechEngine == .parakeet {
            try await ParakeetEngine.shared.loadModel(variant: settings.parakeetVariant)
            return
        }
        guard await TranscriptionEngine.shared.loadedModelId != settings.sttModelId else { return }
        dlog("[Dictum] loading STT model: \(settings.sttModelId)")
        try await TranscriptionEngine.shared.loadModel(settings.sttModelId)
        dlog("[Dictum] STT model loaded")
    }

    func loadLLMModelIfNeeded() async throws {
        guard await !LLMProcessor.shared.isModelLoaded else { return }
        dlog("[Dictum] loading LLM model: \(settings.llmModelId)")
        try await LLMProcessor.shared.loadModel(settings.llmModelId)
        dlog("[Dictum] LLM model loaded")
    }
}
