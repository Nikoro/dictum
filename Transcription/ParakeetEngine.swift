import FluidAudio
import Foundation

actor ParakeetEngine {
    static let shared = ParakeetEngine()

    private var manager: AsrManager?
    private var loadingTask: Task<AsrManager, Error>?

    nonisolated static var isModelDownloaded: Bool {
        AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory(for: .v3), version: .v3)
    }

    func loadModel() async throws {
        if manager != nil {
            return
        }
        if let loadingTask {
            manager = try await loadingTask.value
            return
        }
        let task = Task {
            let models = try await AsrModels.downloadAndLoad(version: .v3)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            return manager
        }
        loadingTask = task
        defer { loadingTask = nil }
        manager = try await task.value
        dlog("[Parakeet] model loaded")
    }

    func transcribe(audioSamples: [Float]) async throws -> String {
        try await loadModel()
        guard let manager else { return "" }
        var decoderState = await TdtDecoderState.make(decoderLayers: manager.decoderLayerCount)
        let result = try await manager.transcribe(audioSamples, decoderState: &decoderState)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func unloadModel() {
        manager = nil
    }
}
