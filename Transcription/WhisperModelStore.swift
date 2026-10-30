import Foundation
import SwiftUI
import WhisperKit

struct SpeechModelInfo: Identifiable {
    let id: String
    let displayName: String
    let sizeBytes: Int64
    let descriptionKey: String
    var isRecommended: Bool = false
    var engine: SpeechEngine = .whisper

    var description: String {
        String(localized: String.LocalizationValue(descriptionKey))
    }

    var formattedSize: String {
        sizeBytes.formattedFileSize
    }
}

@MainActor
@Observable
final class WhisperModelStore {
    static let shared = WhisperModelStore()

    var downloadedModelIds: Set<String> = []
    var isDownloading = false
    var downloadingModelId: String?
    var downloadProgress: Double = 0
    var downloadError: String?
    var cachedTotalSizeOnDisk: Int64 = 0

    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    private static let downloadedKey = UserDefaultsKey.whisperDownloadedModelIds.rawValue

    static let defaultModels: [SpeechModelInfo] = [
        SpeechModelInfo(
            id: "openai_whisper-large-v3_turbo",
            displayName: "Large V3 Turbo",
            sizeBytes: 954_000_000,
            descriptionKey: "stt.large_v3_turbo.desc",
            isRecommended: true
        ),
        SpeechModelInfo(
            id: "openai_whisper-large-v3",
            displayName: "Large V3",
            sizeBytes: 947_000_000,
            descriptionKey: "stt.large_v3.desc"
        ),
        SpeechModelInfo(
            id: "distil-whisper_distil-large-v3_turbo",
            displayName: "Distil Large V3 Turbo",
            sizeBytes: 600_000_000,
            descriptionKey: "stt.distil_large_v3_turbo.desc"
        ),
        SpeechModelInfo(
            id: "openai_whisper-medium",
            displayName: "Medium",
            sizeBytes: 1_500_000_000,
            descriptionKey: "stt.medium.desc"
        ),
        SpeechModelInfo(
            id: "openai_whisper-small",
            displayName: "Small",
            sizeBytes: 216_000_000,
            descriptionKey: "stt.small.desc"
        ),
        SpeechModelInfo(
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
                let modelFolder = try await downloadIntoFirstHalfOfProgress(modelId)
                try Task.checkCancellation()
                try await loadWithEstimatedProgress(fromFolder: modelFolder)
                activate(modelId)
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

    private func downloadIntoFirstHalfOfProgress(_ modelId: String) async throws -> URL {
        try await WhisperKit.download(variant: modelId) { [weak self] progress in
            Task { @MainActor in
                self?.downloadProgress = progress.fractionCompleted * 0.5
            }
        }
    }

    // Edge case: CoreML compilation reports no progress, so the second half of the bar creeps
    // towards 99% over the typical ~120 s instead.
    private func loadWithEstimatedProgress(fromFolder modelFolder: URL) async throws {
        downloadProgress = 0.5
        // Edge case: the block must ignore its Timer argument (not Sendable, so reaching it from
        // the main actor is a cross-isolation send); `defer` invalidates instead. Scheduled from
        // the main actor, the block runs on the main run loop, which makes assumeIsolated safe.
        let loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.downloadProgress < 0.99 else { return }
                self.downloadProgress += Self.estimatedLoadProgressPerTick
            }
        }
        defer { loadingTimer.invalidate() }

        try await TranscriptionEngine.shared.loadModel(fromFolder: modelFolder.path)
        downloadProgress = 1.0
    }

    private func activate(_ modelId: String) {
        downloadedModelIds.insert(modelId)
        AppSettings.shared.sttEngine = .whisper
        AppSettings.shared.sttModelId = modelId
        persistIds()
        refreshTotalSize()
        ModelWarmupCoordinator.shared.switchSpeechModel()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadingModelId = nil
        downloadProgress = 0
    }

    func deleteModel(_ modelId: String) async {
        let settings = AppSettings.shared
        if settings.sttModelId == modelId {
            await TranscriptionEngine.shared.unloadModel()
            settings.sttModelId = Self.defaultModels.first?.id ?? ""
        }
        downloadedModelIds.remove(modelId)
        persistIds()

        await Task.detached(priority: .utility) {
            Self.removeModelFiles(modelId)
        }.value

        refreshTotalSize()
    }

    func refreshTotalSize() {
        let entries = Self.defaultModels
            .filter { downloadedModelIds.contains($0.id) }
            .map { (id: $0.id, fallbackBytes: $0.sizeBytes) }

        Task.detached(priority: .utility) { [weak self] in
            let total = Self.totalSizeOnDisk(for: entries)
            await MainActor.run { [weak self] in self?.cachedTotalSizeOnDisk = total }
        }
    }

    private static let estimatedLoadProgressPerTick = 0.49 / (120 / 0.5)

    private nonisolated static var whisperCacheDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/huggingface/hub")
    }

    private nonisolated static func totalSizeOnDisk(for entries: [(id: String, fallbackBytes: Int64)]) -> Int64 {
        let cacheDir = whisperCacheDir
        var total: Int64 = 0
        for entry in entries {
            if let realSize = modelDirectory(entry.id, cacheDir: cacheDir).map(FileManager.default.directorySize(at:)),
               realSize > 0
            {
                total += realSize
            } else {
                total += entry.fallbackBytes
            }
        }
        return total
    }

    private nonisolated static func modelDirectory(_ modelId: String, cacheDir: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: cacheDir, includingPropertiesForKeys: nil) else {
            return nil
        }
        while let url = enumerator.nextObject() as? URL {
            if url.lastPathComponent == modelId, url.hasDirectoryPath {
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
