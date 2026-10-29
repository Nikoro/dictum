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

    var isWarmingUp: Bool {
        !isWarmedUp && warmupTask != nil
    }

    func preloadModels() {
        guard whisperModelStore.downloadedModelIds.contains(settings.sttModelId) else { return }
        Task {
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
                    group.addTask { await LLMProcessor.shared.warmup() }
                }
            }
            guard !Task.isCancelled else { return }
            isWarmedUp = true
            dlog("[Dictum] warmup complete")
        }
    }

    func waitForWarmup() async {
        await warmupTask?.value
    }

    func loadSTTModelIfNeeded() async throws {
        guard await !TranscriptionEngine.shared.isModelLoaded else { return }
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
