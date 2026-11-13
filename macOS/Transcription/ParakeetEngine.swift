import FluidAudio
import Foundation

actor ParakeetEngine {
    static let shared = ParakeetEngine()

    private var manager: AsrManager?
    private var loadedVariant: ParakeetVariant?
    private var loadingTask: Task<Void, Error>?
    private var loadingVariant: ParakeetVariant?

    func loadModel(variant: ParakeetVariant = .version3, progressHandler: ProgressHandler? = nil) async throws {
        while let existing = loadingTask {
            if loadingVariant == variant {
                return try await existing.value
            }
            _ = try? await existing.value
        }
        guard manager == nil || loadedVariant != variant else { return }
        let task = Task {
            let models = try await AsrModels.downloadAndLoad(version: variant.version, progressHandler: progressHandler)
            let candidate = AsrManager(config: .default)
            try await candidate.loadModels(models)
            try Task.checkCancellation()
            manager = candidate
            loadedVariant = variant
            dlog("[Parakeet] model loaded: \(variant.rawValue)")
        }
        loadingTask = task
        loadingVariant = variant
        defer { loadingTask = nil; loadingVariant = nil }
        try await task.value
    }

    func transcribe(audioSamples: [Float], variant: ParakeetVariant = .version3, language: String? = nil) async throws -> String {
        try await loadModel(variant: variant)
        guard let manager else { return "" }
        var state = await TdtDecoderState.make(decoderLayers: manager.decoderLayerCount)
        let hint = language.flatMap(Language.init(rawValue:))
        let result = try await manager.transcribe(audioSamples, decoderState: &state, language: hint)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func unloadModel() async {
        loadingTask?.cancel()
        _ = try? await loadingTask?.value
        manager = nil
        loadedVariant = nil
    }

    func cancelLoad() {
        loadingTask?.cancel()
    }

    func deleteModel(variant: ParakeetVariant) async throws {
        if loadedVariant == variant || loadingVariant == variant {
            await unloadModel()
        }
        try FileManager.default.removeItem(at: variant.directory)
        dlog("[Parakeet] model files deleted: \(variant.rawValue)")
    }
}
