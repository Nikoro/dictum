import Foundation
import Observation

@MainActor
@Observable
final class LLMModelDownloadController {
    static let shared = LLMModelDownloadController()

    var downloadError: String?
    var isDownloading = false
    var downloadingModelId: String?
    var downloadProgress: Double = 0

    private let settings: AppSettings
    private let downloadedLLMModelStore: DownloadedLLMModelStore
    @ObservationIgnored private var downloadTask: Task<Void, Never>?

    init(settings: AppSettings, downloadedLLMModelStore: DownloadedLLMModelStore) {
        self.settings = settings
        self.downloadedLLMModelStore = downloadedLLMModelStore
    }

    private convenience init() {
        self.init(settings: AppSettings.shared, downloadedLLMModelStore: DownloadedLLMModelStore.shared)
    }

    func downloadModel(_ modelId: String) {
        isDownloading = true
        downloadingModelId = modelId
        downloadProgress = 0
        downloadError = nil

        downloadTask = Task { [weak self] in
            guard let self else { return }

            defer {
                self.isDownloading = false
                self.downloadingModelId = nil
                self.downloadProgress = 0
                self.downloadTask = nil
            }

            do {
                try await LLMProcessor.shared.loadModel(modelId) { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress = progress.fractionCompleted
                    }
                }
                settings.llmModelId = modelId
                downloadedLLMModelStore.scanDownloadedModels()
            } catch is CancellationError {
                dlog("[LLM] download cancelled")
            } catch {
                dlog("[LLM] load after download failed: \(error.localizedDescription)")
                downloadError = error.localizedDescription
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadingModelId = nil
        downloadProgress = 0
    }
}
