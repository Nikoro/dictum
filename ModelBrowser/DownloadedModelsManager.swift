import Foundation
import SwiftUI

struct DownloadedModel: Identifiable {
    let id: String
    let sizeOnDisk: Int64
    var isActive: Bool

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeOnDisk, countStyle: .file)
    }

    var shortName: String {
        id.replacingOccurrences(of: "mlx-community/", with: "")
    }
}

@MainActor
final class DownloadedModelsManager: ObservableObject {
    static let shared = DownloadedModelsManager()

    @Published var downloadedModels: [DownloadedModel] = []

    private var cacheDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
    }

    private init() {
        scanDownloadedModels()
    }

    func scanDownloadedModels() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: nil
        ) else {
            downloadedModels = []
            return
        }

        let activeModelId = AppSettings.shared.llmModelId

        downloadedModels = contents
            .filter { $0.lastPathComponent.hasPrefix("models--mlx-community--") }
            .compactMap { url -> DownloadedModel? in
                let name = url.lastPathComponent
                    .replacingOccurrences(of: "models--", with: "")
                    .replacingOccurrences(of: "--", with: "/")
                let size = directorySize(url)
                return DownloadedModel(
                    id: name,
                    sizeOnDisk: size,
                    isActive: name == activeModelId
                )
            }
            .sorted { $0.sizeOnDisk > $1.sizeOnDisk }
    }

    func deleteModel(_ modelId: String) throws {
        let folderName = "models--" + modelId.replacingOccurrences(of: "/", with: "--")
        let modelDir = cacheDir.appendingPathComponent(folderName)
        try FileManager.default.removeItem(at: modelDir)
        scanDownloadedModels()
    }

    var totalSizeOnDisk: Int64 {
        downloadedModels.map(\.sizeOnDisk).reduce(0, +)
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeOnDisk, countStyle: .file)
    }

    private func directorySize(_ url: URL) -> Int64 {
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey]
        )
        var total: Int64 = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }
}
