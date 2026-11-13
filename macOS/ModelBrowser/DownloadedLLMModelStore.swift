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

    private init() {
        scanDownloadedModels()
    }

    func scanDownloadedModels() {
        let modelIds = Set(LLMModelStorage.installedModels().map(\.id))
        downloadedModels = modelIds
            .compactMap { modelId -> DownloadedLLMModel? in
                let size = LLMModelStorage.directories(of: modelId)
                    .map(FileManager.default.directorySize(at:))
                    .reduce(0, +)
                return size > 0 ? DownloadedLLMModel(id: modelId, sizeOnDisk: size) : nil
            }
            .sorted { $0.sizeOnDisk > $1.sizeOnDisk }
    }

    func deleteModel(_ modelId: String) throws {
        try LLMModelStorage.delete(modelId)
        scanDownloadedModels()
    }

    var totalSizeOnDisk: Int64 {
        downloadedModels.map(\.sizeOnDisk).reduce(0, +)
    }
}
