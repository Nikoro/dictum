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
final class WhisperModelStore: ObservableObject {
    static let shared = WhisperModelStore()

    @Published var availableModels: [WhisperModelInfo] = WhisperModelStore.defaultModels
    @Published var downloadedModelIds: Set<String> = []
    @Published var activeModelId: String = "openai_whisper-large-v3_turbo"
    @Published var isDownloading = false
    @Published var downloadingModelId: String?
    @Published var downloadProgress: Double = 0
    @Published var downloadError: String?
    @Published var cachedTotalSizeOnDisk: Int64 = 0

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
        )
    ]

    private init() {
        loadPersistedIds()
        refreshTotalSize()
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
        downloadError = nil

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
                // The block ignores its Timer argument — Timer is not Sendable, so passing it
                // into the main-actor body would be a cross-isolation send. The defer below
                // owns invalidation regardless of how this scope exits.
                let loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    // Scheduled from the main actor, so the block fires on the main run loop.
                    MainActor.assumeIsolated {
                        guard let self, self.downloadProgress < 0.99 else { return }
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
                refreshTotalSize()
                DictationPipeline.shared.warmUpModels()
            } catch is CancellationError {
                dlog("[STT] download cancelled")
            } catch {
                dlog("[STT] download failed: \(error)")
                downloadError = error.localizedDescription
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

    func deleteModel(_ modelId: String) async {
        if activeModelId == modelId {
            await TranscriptionEngine.shared.unloadModel()
        }
        downloadedModelIds.remove(modelId)
        if activeModelId == modelId {
            activeModelId = Self.defaultModels.first?.id ?? ""
        }
        persistIds()

        await Task.detached(priority: .utility) {
            Self.removeModelFiles(modelId)
        }.value

        refreshTotalSize()
    }

    /// Recomputes the on-disk total in the background. Walking the HuggingFace cache means
    /// enumerating multiple gigabytes of model files, which must not happen on the main actor.
    func refreshTotalSize() {
        let entries = Self.defaultModels
            .filter { downloadedModelIds.contains($0.id) }
            .map { (id: $0.id, fallbackBytes: $0.sizeBytes) }

        Task.detached(priority: .utility) { [weak self] in
            let total = Self.totalSizeOnDisk(for: entries)
            await MainActor.run { [weak self] in self?.cachedTotalSizeOnDisk = total }
        }
    }

    // MARK: - Disk access (off the main actor)

    /// WhisperKit downloads models to ~/Library/Caches/huggingface/hub/
    private nonisolated static var whisperCacheDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/huggingface/hub")
    }

    private nonisolated static func totalSizeOnDisk(for entries: [(id: String, fallbackBytes: Int64)]) -> Int64 {
        let cacheDir = whisperCacheDir
        var total: Int64 = 0
        for entry in entries {
            if let realSize = modelDirectory(entry.id, cacheDir: cacheDir).map(FileManager.default.directorySize(at:)),
               realSize > 0 {
                total += realSize
            } else {
                total += entry.fallbackBytes // fallback to estimate
            }
        }
        return total
    }

    /// WhisperKit stores models under models--argmaxinc--whisperkit-coreml/snapshots/*/modelId/
    private nonisolated static func modelDirectory(_ modelId: String, cacheDir: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: cacheDir, includingPropertiesForKeys: nil) else {
            return nil
        }
        while let url = enumerator.nextObject() as? URL {
            if url.lastPathComponent == modelId && url.hasDirectoryPath {
                return url
            }
        }
        return nil
    }

    private nonisolated static func removeModelFiles(_ modelId: String) {
        guard let url = modelDirectory(modelId, cacheDir: whisperCacheDir) else { return }
        try? FileManager.default.removeItem(at: url)
        dlog("[STT] deleted model files at \(url.path)")
    }
}
