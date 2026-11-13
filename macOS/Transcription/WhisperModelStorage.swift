import Foundation

struct WhisperModelStorage: Sendable {
    static let standard = WhisperModelStorage(
        downloadBase: LLMModelStorage.legacyRoot.appendingPathComponent("whisperkit"),
        legacyDownloadBase: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("huggingface")
    )

    private static let modelRepoPath = "models/argmaxinc/whisperkit-coreml"
    private static let tokenizerRepoPaths = ["models/openai", "models/distil-whisper"]

    let downloadBase: URL
    let legacyDownloadBase: URL

    func modelFolder(for modelId: String) -> URL {
        downloadBase.appendingPathComponent(Self.modelRepoPath).appendingPathComponent(modelId)
    }

    func sizeOnDisk(of modelId: String) -> Int64 {
        FileManager.default.directorySize(at: modelFolder(for: modelId))
    }

    func delete(_ modelId: String) throws {
        try FileManager.default.removeItem(at: modelFolder(for: modelId))
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: downloadBase)
    }

    func needsMigration(_ modelIds: some Sequence<String>) -> Bool {
        modelIds.contains { !FileManager.default.fileExists(atPath: modelFolder(for: $0).path) }
    }

    func migrateLegacyModels(_ modelIds: some Sequence<String>) -> [String] {
        let fileManager = FileManager.default
        let legacyModels = legacyDownloadBase.appendingPathComponent(Self.modelRepoPath)
        let moved = modelIds.filter { modelId in
            let source = legacyModels.appendingPathComponent(modelId)
            let target = modelFolder(for: modelId)
            guard fileManager.fileExists(atPath: source.path), !fileManager.fileExists(atPath: target.path) else {
                return false
            }
            do {
                try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.moveItem(at: source, to: target)
                return true
            } catch {
                dlog("[STT] moving \(modelId) out of Documents failed: \(error)")
                return false
            }
        }
        if !moved.isEmpty {
            copyLegacyTokenizers()
        }
        return moved
    }

    private func copyLegacyTokenizers() {
        let fileManager = FileManager.default
        for repoPath in Self.tokenizerRepoPaths {
            let sourceRoot = legacyDownloadBase.appendingPathComponent(repoPath)
            let targetRoot = downloadBase.appendingPathComponent(repoPath)
            let tokenizers = (try? fileManager.contentsOfDirectory(at: sourceRoot, includingPropertiesForKeys: nil)) ?? []
            for tokenizer in tokenizers where tokenizer.hasDirectoryPath {
                let target = targetRoot.appendingPathComponent(tokenizer.lastPathComponent)
                guard !fileManager.fileExists(atPath: target.path) else { continue }
                try? fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
                try? fileManager.copyItem(at: tokenizer, to: target)
            }
        }
    }
}
