import Foundation
import SwiftUI
import WhisperKit

struct WhisperModelInfo: Identifiable {
    let id: String
    let displayName: String
    let sizeBytes: Int64
    let descriptionKey: String
    var isRecommended: Bool = false

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
    @Published var downloadProgress: Double = 0

    private var downloadTask: Task<Void, Never>?
    private static let downloadedKey = UserDefaultsKey.whisperDownloadedModelIds.rawValue

    static let defaultModels: [WhisperModelInfo] = [
        WhisperModelInfo(
            id: "openai_whisper-large-v3_turbo",
            displayName: "Large V3 Turbo",
            sizeBytes: 954_000_000,
            descriptionKey: "stt.large_v3_turbo.desc",
            isRecommended: true
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

    func downloadAndActivate(_ modelId: String) {
        isDownloading = true
        downloadingModelId = modelId
        downloadProgress = 0

        downloadTask = Task {
            do {
                let modelFolder = try await WhisperKit.download(variant: modelId) { [weak self] progress in
                    Task { @MainActor in
                        // Download = 0% to 50%
                        self?.downloadProgress = progress.fractionCompleted * 0.5
                    }
                }

                try Task.checkCancellation()

                // Simulate loading progress from 50% to 99% over ~120s
                downloadProgress = 0.5
                let loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                    guard let self else { timer.invalidate(); return }
                    if self.downloadProgress < 0.99 {
                        // 0.49 / 240 ticks (120s / 0.5s) ≈ 0.002 per tick
                        self.downloadProgress += 0.002
                    }
                }
                defer { loadingTimer.invalidate() }

                try await TranscriptionEngine.shared.loadModel(fromFolder: modelFolder.path)
                downloadProgress = 1.0

                downloadedModelIds.insert(modelId)
                activeModelId = modelId
                AppSettings.shared.sttModelId = modelId
                persistIds()
                DictationPipeline.shared.warmUpModels()
            } catch is CancellationError {
                dlog("[STT] download cancelled")
            } catch {
                dlog("[STT] download failed: \(error)")
            }
            isDownloading = false
            downloadingModelId = nil
            downloadProgress = 0
            downloadTask = nil
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadingModelId = nil
        downloadProgress = 0
    }

    /// WhisperKit downloads models to ~/Library/Caches/huggingface/hub/
    private var whisperCacheDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/huggingface/hub")
    }

    func deleteModel(_ modelId: String) {
        downloadedModelIds.remove(modelId)
        if activeModelId == modelId {
            activeModelId = Self.defaultModels.first?.id ?? ""
        }
        persistIds()

        // Delete model files from disk
        // WhisperKit stores models under models--argmaxinc--whisperkit-coreml/snapshots/*/modelId/
        let cacheDir = whisperCacheDir
        if let enumerator = FileManager.default.enumerator(at: cacheDir, includingPropertiesForKeys: nil) {
            while let url = enumerator.nextObject() as? URL {
                if url.lastPathComponent == modelId && url.hasDirectoryPath {
                    try? FileManager.default.removeItem(at: url)
                    dlog("[STT] deleted model files at \(url.path)")
                    break
                }
            }
        }
    }

    func totalSizeOnDisk() -> Int64 {
        var total: Int64 = 0
        let cacheDir = whisperCacheDir
        for model in Self.defaultModels where downloadedModelIds.contains(model.id) {
            if let realSize = modelSizeOnDisk(model.id, cacheDir: cacheDir), realSize > 0 {
                total += realSize
            } else {
                total += model.sizeBytes // fallback to estimate
            }
        }
        return total
    }

    private func modelSizeOnDisk(_ modelId: String, cacheDir: URL) -> Int64? {
        guard let enumerator = FileManager.default.enumerator(at: cacheDir, includingPropertiesForKeys: nil) else { return nil }
        while let url = enumerator.nextObject() as? URL {
            if url.lastPathComponent == modelId && url.hasDirectoryPath {
                return directorySize(url)
            }
        }
        return nil
    }

    private func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }
}
