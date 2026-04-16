import Foundation
import SwiftUI

struct DownloadedLLMModel: Identifiable {
    let id: String
    let sizeOnDisk: Int64
    var isActive: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeOnDisk, countStyle: .file)
    }

    var shortName: String {
        ModelConstants.shortModelName(id)
    }
}

@MainActor
final class DownloadedLLMModelStore: ObservableObject {
    static let shared = DownloadedLLMModelStore()

    @Published var downloadedModels: [DownloadedLLMModel] = []

    /// MLX Swift downloads to ~/Library/Caches/models/
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
        ) else {
            downloadedModels = []
            return
        }

        let activeModelId = AppSettings.shared.llmModelId

        downloadedModels = contents
            .filter { $0.hasDirectoryPath }
            .compactMap { url -> DownloadedLLMModel? in
                let folderName = url.lastPathComponent
                let modelId = ModelConstants.mlxCommunityPrefix + folderName
                let size = directorySize(url)
                guard size > 0 else { return nil }
                return DownloadedLLMModel(
                    id: modelId,
                    sizeOnDisk: size,
                    isActive: modelId == activeModelId
                )
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

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeOnDisk, countStyle: .file)
    }

    private func directorySize(_ url: URL) -> Int64 {
        FileManager.default.directorySize(at: url)
    }
}
