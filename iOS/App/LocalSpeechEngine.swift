import FluidAudio
import Foundation

actor LocalSpeechEngine {
    private var manager: AsrManager?
    private var loadedVersion: AsrModelVersion?

    func prepare(ultra: Bool, progress: ProgressHandler?) async throws {
        let version: AsrModelVersion = ultra ? .ultra : .v3
        guard manager == nil || loadedVersion != version else { return }
        manager = nil
        loadedVersion = nil
        let models = try await AsrModels.downloadAndLoad(version: version, progressHandler: progress)
        try Task.checkCancellation()
        let candidate = AsrManager(config: .default)
        try await candidate.loadModels(models)
        try Task.checkCancellation()
        manager = candidate
        loadedVersion = version
    }

    func transcribe(file: URL, languageCode: String? = "pl") async throws -> String {
        guard let manager else { throw CocoaError(.coderValueNotFound) }
        let samples = try AudioConverter().resampleAudioFile(file)
        guard !samples.isEmpty else { return "" }
        var state = await TdtDecoderState.make(decoderLayers: manager.decoderLayerCount)
        let hint = languageCode.flatMap(Language.init(rawValue:))
        let result = try await manager.transcribe(samples, decoderState: &state, language: hint)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func storageBytes(ultra: Bool) -> Int64? {
        let directory = AsrModels.defaultCacheDirectory(for: ultra ? .ultra : .v3)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: Array(keys)) else {
            return nil
        }
        var bytes: Int64 = 0
        for case let url as URL in files {
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            bytes += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return bytes > 0 ? bytes : nil
    }

    func installations() -> [IOSSpeechModel: IOSModelInstallation] {
        Dictionary(uniqueKeysWithValues: IOSSpeechModel.allCases.map { model in
            let version: AsrModelVersion = model.usesUltra ? .ultra : .v3
            let directory = AsrModels.defaultCacheDirectory(for: version)
            return (model, IOSModelInstallation(
                installed: AsrModels.modelsExist(at: directory, version: version),
                bytes: storageBytes(ultra: model.usesUltra)
            ))
        })
    }
}
