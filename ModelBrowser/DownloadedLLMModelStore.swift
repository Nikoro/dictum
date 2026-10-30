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
        downloadedModels = LLMModelStorage.installedModels()
            .compactMap { model -> DownloadedLLMModel? in
                let size = FileManager.default.directorySize(at: model.directory)
                return size > 0 ? DownloadedLLMModel(id: model.id, sizeOnDisk: size) : nil
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
