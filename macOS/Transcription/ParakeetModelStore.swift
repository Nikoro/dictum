import Foundation
import Observation

@Observable
@MainActor
final class ParakeetModelStore {
    static let shared = ParakeetModelStore()
    static let models = ParakeetVariant.allCases.map(\.model)

    private(set) var downloadedVariants = Set(ParakeetVariant.allCases.filter(\.isDownloaded))
    private(set) var downloadingVariant: ParakeetVariant?
    private(set) var downloadProgress: Double = 0
    private(set) var sizes: [ParakeetVariant: Int64] = [:]
    var downloadError: String?

    @ObservationIgnored private var downloadTask: Task<Void, Never>?

    var isDownloaded: Bool {
        downloadedVariants.contains(AppSettings.shared.parakeetVariant)
    }

    var isDownloading: Bool {
        downloadingVariant != nil
    }

    private init() {
        refreshSize()
    }

    func downloadAndActivate(_ variant: ParakeetVariant) {
        guard !isDownloading else { return }
        downloadingVariant = variant
        downloadProgress = 0
        downloadError = nil
        downloadTask = Task {
            do {
                try await ParakeetEngine.shared.loadModel(variant: variant) { [weak self] progress in
                    Task { @MainActor in self?.downloadProgress = progress.fractionCompleted }
                }
                try Task.checkCancellation()
                downloadedVariants.insert(variant)
                refreshSize()
                AppSettings.shared.parakeetVariant = variant
                AppSettings.shared.sttEngine = .parakeet
                ModelWarmupCoordinator.shared.switchSpeechModel()
            } catch is CancellationError {
                dlog("[Parakeet] download cancelled")
            } catch {
                dlog("[Parakeet] download failed: \(error)")
                downloadError = error.localizedDescription
            }
            downloadingVariant = nil
            downloadProgress = 0
            downloadTask = nil
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        Task { await ParakeetEngine.shared.cancelLoad() }
    }

    func deleteModel(_ variant: ParakeetVariant) async {
        do {
            try await ParakeetEngine.shared.deleteModel(variant: variant)
        } catch {
            dlog("[Parakeet] delete failed: \(error)")
            downloadError = error.localizedDescription
        }
        downloadedVariants = Set(ParakeetVariant.allCases.filter(\.isDownloaded))
        if AppSettings.shared.sttEngine == .parakeet, !isDownloaded {
            AppSettings.shared.sttEngine = .whisper
        }
        refreshSize()
    }

    private func refreshSize() {
        Task.detached(priority: .utility) { [weak self] in
            let sizes = Dictionary(uniqueKeysWithValues: ParakeetVariant.allCases.map {
                ($0, FileManager.default.directorySize(at: $0.directory))
            })
            await MainActor.run { [weak self] in self?.sizes = sizes }
        }
    }
}
