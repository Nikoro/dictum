import Foundation
import SwiftUI

struct DownloadedLLMModel: Identifiable {
    let id: String
    let sizeOnDisk: Int64

    var formattedSize: String {
        sizeOnDisk.formattedFileSize
    }

    var shortName: String {
        ModelConstants.shortModelName(id)
    }
}

@MainActor
@Observable
final class DownloadedLLMModelStore {
    static let shared = DownloadedLLMModelStore()

    var downloadedModels: [DownloadedLLMModel] = []

    private var mlxCacheDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/models/mlx-community")
    }

    private init() {
        scanDownloadedModels()
    }

    func scanDownloadedModels() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: mlxCacheDir,
            includingPropertiesForKeys: nil
        )
        else {
            downloadedModels = []
            return
        }

        downloadedModels = contents
            .filter(\.hasDirectoryPath)
            .compactMap { url -> DownloadedLLMModel? in
                let folderName = url.lastPathComponent
                let modelId = ModelConstants.mlxCommunityPrefix + folderName
                let size = directorySize(url)
                guard size > 0 else { return nil }
                return DownloadedLLMModel(id: modelId, sizeOnDisk: size)
            }
            .sorted { $0.sizeOnDisk > $1.sizeOnDisk }
    }

    func deleteModel(_ modelId: String) throws {
        let folderName = ModelConstants.shortModelName(modelId)
        let modelDir = mlxCacheDir.appendingPathComponent(folderName)
        let resolved = modelDir.standardizedFileURL
        let cacheRoot = mlxCacheDir.standardizedFileURL.path + "/"
        guard resolved.path.hasPrefix(cacheRoot) else {
            throw NSError(
                domain: "DownloadedLLMModelStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid model id: \(modelId)"]
            )
        }
        try FileManager.default.removeItem(at: resolved)
        scanDownloadedModels()
    }

    var totalSizeOnDisk: Int64 {
        downloadedModels.map(\.sizeOnDisk).reduce(0, +)
    }

    private func directorySize(_ url: URL) -> Int64 {
        FileManager.default.directorySize(at: url)
    }
}
