import Darwin
import Foundation
import HuggingFace
import MLXLMCommon

struct InstalledLLMModel {
    let id: String
    let directory: URL
}

// Edge case: models downloaded before swift-transformers 1.2 live in ~/Library/Caches/models
// as plain <org>/<name> folders; newer ones in the Hugging Face cache. Both stay usable, so an
// upgrade never re-downloads gigabytes.
enum LLMModelStorage {
    static let organization = "mlx-community"
    static let hubCache = HubCache.default
    static let legacyRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/models")

    private static var hubRepoPrefix: String {
        "models--\(organization)--"
    }

    static func installedModels() -> [InstalledLLMModel] {
        storedModels().filter { !$0.id.contains("-assistant-") }
    }

    private static func storedModels() -> [InstalledLLMModel] {
        legacyModels() + hubCachedModels()
    }

    static func delete(_ modelId: String) throws {
        let directories = installedModels().filter { $0.id == modelId }.map(\.directory)
        guard !directories.isEmpty else { throw CocoaError(.fileNoSuchFile) }
        for directory in directories {
            try FileManager.default.removeItem(at: directory)
        }
    }

    static func deleteAll() {
        for model in storedModels() {
            try? FileManager.default.removeItem(at: model.directory)
        }
    }

    static func legacyFolder(for modelId: String) -> URL? {
        let folder = legacyRoot.appendingPathComponent(modelId).standardizedFileURL
        guard folder.path.hasPrefix(legacyRoot.standardizedFileURL.path + "/"),
              FileManager.default.fileExists(atPath: folder.appendingPathComponent("config.json").path)
        else {
            return nil
        }
        return folder
    }

    // Edge case: swift-transformers 1.1 fetched no chat_template.jinja and worked without it;
    // 1.2+ refuses to apply a chat without one, so old folders need their sidecar files topped up.
    static func hasChatTemplate(_ folder: URL) -> Bool {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: folder.appendingPathComponent("chat_template.jinja").path)
            || fileManager.fileExists(atPath: folder.appendingPathComponent("chat_template.json").path)
        {
            return true
        }
        let tokenizerConfig = folder.appendingPathComponent("tokenizer_config.json")
        guard let data = try? Data(contentsOf: tokenizerConfig),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return false
        }
        return json["chat_template"] != nil
    }

    static func matches(_ path: String, anyOf patterns: [String]) -> Bool {
        patterns.isEmpty || patterns.contains { fnmatch($0, path, 0) == 0 }
    }

    private static func legacyModels() -> [InstalledLLMModel] {
        let organizationFolder = legacyRoot.appendingPathComponent(organization)
        return subdirectories(of: organizationFolder).map { folder in
            InstalledLLMModel(id: "\(organization)/\(folder.lastPathComponent)", directory: folder)
        }
    }

    private static func hubCachedModels() -> [InstalledLLMModel] {
        subdirectories(of: hubCache.cacheDirectory)
            .filter { $0.lastPathComponent.hasPrefix(hubRepoPrefix) }
            .map { repoDirectory in
                let name = String(repoDirectory.lastPathComponent.dropFirst(hubRepoPrefix.count))
                return InstalledLLMModel(id: "\(organization)/\(name)", directory: repoDirectory)
            }
    }

    private static func subdirectories(of directory: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return contents.filter(\.hasDirectoryPath)
    }
}

struct OfflineFirstHubDownloader: MLXLMCommon.Downloader {
    private let client = HubClient(cache: LLMModelStorage.hubCache)

    // Edge case: a complete local copy is used without touching the network, so a model loads
    // offline and app launch does not depend on huggingface.co being reachable.
    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repo = Repo.ID(rawValue: id) else {
            throw LLMError.invalidModelId(id)
        }
        let revision = revision ?? "main"
        if !useLatest, let legacyFolder = LLMModelStorage.legacyFolder(for: id) {
            if !LLMModelStorage.hasChatTemplate(legacyFolder) {
                try await topUpSidecarFiles(in: legacyFolder, repo: repo, revision: revision, patterns: patterns)
            }
            return legacyFolder
        }
        if !useLatest,
           let cached = try? await client.downloadSnapshot(of: repo, revision: revision, matching: patterns, localFilesOnly: true)
        {
            return cached
        }
        return try await client.downloadSnapshot(of: repo, revision: revision, matching: patterns) { @MainActor progress in
            progressHandler(progress)
        }
    }

    private func topUpSidecarFiles(in folder: URL, repo: Repo.ID, revision: String, patterns: [String]) async throws {
        let missing = try await client.listFiles(in: repo, revision: revision).filter { entry in
            entry.lfs == nil
                && LLMModelStorage.matches(entry.path, anyOf: patterns)
                && !FileManager.default.fileExists(atPath: folder.appendingPathComponent(entry.path).path)
        }
        for entry in missing {
            let data = try await client.downloadContentsOfFile(at: entry.path, from: repo, revision: revision)
            try data.write(to: folder.appendingPathComponent(entry.path))
        }
        dlog("[LLM] topped up \(missing.count) sidecar files of a pre-1.2 model folder")
    }
}
