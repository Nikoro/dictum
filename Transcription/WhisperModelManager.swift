import Foundation
import SwiftUI

struct WhisperModelInfo: Identifiable {
    let id: String
    let displayName: String
    let sizeBytes: Int64
    let descriptionKey: String

    var description: String {
        String(localized: String.LocalizationValue(descriptionKey))
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

@MainActor
final class WhisperModelManager: ObservableObject {
    static let shared = WhisperModelManager()

    @Published var availableModels: [WhisperModelInfo] = WhisperModelManager.defaultModels
    @Published var downloadedModelIds: Set<String> = []
    @Published var activeModelId: String = "openai_whisper-large-v3_turbo"
    @Published var isDownloading = false
    @Published var downloadingModelId: String?

    private static let downloadedKey = "whisperDownloadedModelIds"

    static let defaultModels: [WhisperModelInfo] = [
        WhisperModelInfo(
            id: "openai_whisper-large-v3_turbo",
            displayName: "Large V3 Turbo",
            sizeBytes: 954_000_000,
            descriptionKey: "stt.large_v3_turbo.desc"
        ),
        WhisperModelInfo(
            id: "openai_whisper-large-v3",
            displayName: "Large V3",
            sizeBytes: 947_000_000,
            descriptionKey: "stt.large_v3.desc"
        ),
        WhisperModelInfo(
            id: "distil-whisper_distil-large-v3_turbo",
            displayName: "Distil Large V3 Turbo",
            sizeBytes: 600_000_000,
            descriptionKey: "stt.distil_large_v3_turbo.desc"
        ),
        WhisperModelInfo(
            id: "openai_whisper-medium",
            displayName: "Medium",
            sizeBytes: 1_500_000_000,
            descriptionKey: "stt.medium.desc"
        ),
        WhisperModelInfo(
            id: "openai_whisper-small",
            displayName: "Small",
            sizeBytes: 216_000_000,
            descriptionKey: "stt.small.desc"
        ),
        WhisperModelInfo(
            id: "openai_whisper-base",
            displayName: "Base",
            sizeBytes: 150_000_000,
            descriptionKey: "stt.base.desc"
        ),
    ]

    private init() {
        loadPersistedIds()
    }

    private func loadPersistedIds() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.downloadedKey) ?? []
        downloadedModelIds = Set(saved)
    }

    private func persistIds() {
        UserDefaults.standard.set(Array(downloadedModelIds), forKey: Self.downloadedKey)
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
        persistIds()
    }

    func deleteModel(_ modelId: String) {
        downloadedModelIds.remove(modelId)
        if activeModelId == modelId {
            activeModelId = Self.defaultModels.first?.id ?? ""
        }
        persistIds()
    }

    func totalSizeOnDisk() -> Int64 {
        var total: Int64 = 0
        for model in Self.defaultModels where downloadedModelIds.contains(model.id) {
            total += model.sizeBytes
        }
        return total
    }
}
