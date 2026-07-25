import Foundation
import Combine

@MainActor
final class LLMModelDownloadController: ObservableObject {
    @Published var downloadError: String?
    @Published var isDownloading = false
    @Published var downloadingModelId: String?
    @Published var downloadProgress: Double = 0

    private let settings: AppSettings
    private let downloadedLLMModelStore: DownloadedLLMModelStore
    private var downloadTask: Task<Void, Never>?

    init(settings: AppSettings, downloadedLLMModelStore: DownloadedLLMModelStore) {
        self.settings = settings
        self.downloadedLLMModelStore = downloadedLLMModelStore
    }

    convenience init() {
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
                // Only adopt the model once it actually loaded, otherwise the user is left
                // with a selected model that does not exist on disk.
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
