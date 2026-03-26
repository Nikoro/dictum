import Foundation
import SwiftUI

struct WhisperModelInfo: Identifiable {
    let id: String
    let displayName: String
    let sizeBytes: Int64
    let description: String

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

@MainActor
final class WhisperModelManager: ObservableObject {
    static let shared = WhisperModelManager()

    @Published var availableModels: [WhisperModelInfo] = WhisperModelManager.defaultModels
    @Published var downloadedModelIds: Set<String> = []
    @Published var activeModelId: String = "large-v3-turbo"
    @Published var isDownloading = false
    @Published var downloadingModelId: String?

    static let defaultModels: [WhisperModelInfo] = [
        WhisperModelInfo(
            id: "large-v3-turbo",
            displayName: "Large V3 Turbo",
            sizeBytes: 1_600_000_000,
            description: "Rekomendowany. Najlepszy balans szybkości i dokładności."
        ),
        WhisperModelInfo(
            id: "large-v3",
            displayName: "Large V3",
            sizeBytes: 3_100_000_000,
            description: "Najwyższa dokładność. 2x wolniejszy niż Turbo."
        ),
        WhisperModelInfo(
            id: "distil-large-v3",
            displayName: "Distil Large V3",
            sizeBytes: 1_500_000_000,
            description: "Dystylowany. Szybki, dobry dla angielskiego."
        ),
        WhisperModelInfo(
            id: "medium",
            displayName: "Medium",
            sizeBytes: 1_500_000_000,
            description: "Dobra dokładność, umiarkowany rozmiar."
        ),
        WhisperModelInfo(
            id: "small",
            displayName: "Small",
            sizeBytes: 500_000_000,
            description: "Kompromis między rozmiarem a dokładnością."
        ),
        WhisperModelInfo(
            id: "base",
            displayName: "Base",
            sizeBytes: 150_000_000,
            description: "Bardzo mały i szybki. Niższa dokładność."
        ),
    ]

    private init() {
        scanDownloaded()
    }

    func scanDownloaded() {
        // WhisperKit stores models in application support or caches
        // Check common WhisperKit cache locations
        let possiblePaths = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/huggingface/models--argmaxinc--whisperkit-coreml"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".cache/huggingface/hub/models--argmaxinc--whisperkit-coreml"),
        ]

        for path in possiblePaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: path,
                includingPropertiesForKeys: nil
            ) else { continue }

            // WhisperKit models are stored as subdirectories
            for model in Self.defaultModels {
                let modelDirName = "openai_whisper-\(model.id)"
                if contents.contains(where: { $0.lastPathComponent.contains(modelDirName) || $0.lastPathComponent.contains(model.id) }) {
                    downloadedModelIds.insert(model.id)
                }
            }
        }
    }

    func downloadAndActivate(_ modelId: String) async throws {
        isDownloading = true
        downloadingModelId = modelId
        defer {
            isDownloading = false
            downloadingModelId = nil
        }

        try await TranscriptionEngine.shared.loadModel(modelId)
        downloadedModelIds.insert(modelId)
        activeModelId = modelId
        AppSettings.shared.sttModelId = modelId
    }

    func deleteModel(_ modelId: String) {
        let possiblePaths = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/huggingface/models--argmaxinc--whisperkit-coreml"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".cache/huggingface/hub/models--argmaxinc--whisperkit-coreml"),
        ]

        for basePath in possiblePaths {
            let modelDir = basePath.appendingPathComponent("openai_whisper-\(modelId)")
            try? FileManager.default.removeItem(at: modelDir)
        }

        downloadedModelIds.remove(modelId)
        if activeModelId == modelId {
            activeModelId = Self.defaultModels.first?.id ?? "large-v3-turbo"
        }
        scanDownloaded()
    }

    func totalSizeOnDisk() -> Int64 {
        var total: Int64 = 0
        for model in Self.defaultModels where downloadedModelIds.contains(model.id) {
            total += model.sizeBytes
        }
        return total
    }
}
