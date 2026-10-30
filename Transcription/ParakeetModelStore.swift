import Foundation
import Observation

@Observable
@MainActor
final class ParakeetModelStore {
    static let shared = ParakeetModelStore()

    static let model = SpeechModelInfo(
        id: "parakeet-tdt-0.6b-v3",
        displayName: "Parakeet TDT v3",
        sizeBytes: 480_000_000,
        descriptionKey: "stt.parakeet_v3.desc",
        engine: .parakeet
    )

    private(set) var isDownloaded = ParakeetEngine.isModelDownloaded
    private(set) var isDownloading = false
    private(set) var downloadProgress: Double = 0
    private(set) var sizeOnDisk: Int64 = 0
    var downloadError: String?

    @ObservationIgnored private var downloadTask: Task<Void, Never>?

    private init() {
        refreshSize()
    }

    func downloadAndActivate() {
        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0
        downloadError = nil
        downloadTask = Task {
            do {
                try await ParakeetEngine.shared.loadModel { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress = progress.fractionCompleted
                    }
                }
                try Task.checkCancellation()
                isDownloaded = true
                refreshSize()
                AppSettings.shared.sttEngine = .parakeet
                ModelWarmupCoordinator.shared.switchSpeechModel()
            } catch is CancellationError {
                dlog("[Parakeet] download cancelled")
            } catch {
                dlog("[Parakeet] download failed: \(error)")
                downloadError = error.localizedDescription
            }
            isDownloading = false
            downloadProgress = 0
            downloadTask = nil
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
    }

    func deleteModel() async {
        do {
            try await ParakeetEngine.shared.deleteModel()
        } catch {
            dlog("[Parakeet] delete failed: \(error)")
            downloadError = error.localizedDescription
        }
        isDownloaded = ParakeetEngine.isModelDownloaded
        if AppSettings.shared.sttEngine == .parakeet {
            AppSettings.shared.sttEngine = .whisper
        }
        refreshSize()
    }

    private func refreshSize() {
        Task.detached(priority: .utility) { [weak self] in
            let size = FileManager.default.directorySize(at: ParakeetEngine.modelDirectory)
            await MainActor.run { [weak self] in self?.sizeOnDisk = size }
        }
    }
}
