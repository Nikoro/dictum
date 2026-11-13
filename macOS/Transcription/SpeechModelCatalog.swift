import Foundation

@MainActor
struct SpeechModelCatalog {
    let settings: AppSettings
    let whisper: WhisperModelStore
    let parakeet: ParakeetModelStore

    static let models = WhisperModelStore.defaultModels + ParakeetModelStore.models

    var downloadedModels: [SpeechModelInfo] {
        Self.models.filter(isDownloaded)
    }

    var availableModels: [SpeechModelInfo] {
        Self.models.filter { !isDownloaded($0) }
    }

    var activeEngine: SpeechEngine {
        settings.sttEngine == .parakeet && parakeet.isDownloaded ? .parakeet : .whisper
    }

    var hasActiveModel: Bool {
        downloadedModels.contains(where: isActive)
    }

    var downloadError: String? {
        parakeet.downloadError ?? whisper.downloadError
    }

    var totalSizeOnDisk: Int64 {
        whisper.cachedTotalSizeOnDisk + parakeet.sizes.values.reduce(0, +)
    }

    func isDownloaded(_ model: SpeechModelInfo) -> Bool {
        switch model.engine {
        case .whisper: whisper.downloadedModelIds.contains(model.id)
        case .parakeet: ParakeetVariant(rawValue: model.id).map { parakeet.downloadedVariants.contains($0) } ?? false
        }
    }

    func isActive(_ model: SpeechModelInfo) -> Bool {
        model.engine == activeEngine
            && model.id == (model.engine == .parakeet ? settings.parakeetVariant.rawValue : settings.sttModelId)
    }

    func isDownloading(_ model: SpeechModelInfo) -> Bool {
        switch model.engine {
        case .whisper: whisper.downloadingModelId == model.id
        case .parakeet: parakeet.downloadingVariant?.rawValue == model.id
        }
    }

    func downloadProgress(of model: SpeechModelInfo) -> Double {
        guard isDownloading(model) else { return 0 }
        return model.engine == .parakeet ? parakeet.downloadProgress : whisper.downloadProgress
    }

    func formattedSize(of model: SpeechModelInfo) -> String {
        if let variant = ParakeetVariant(rawValue: model.id), let size = parakeet.sizes[variant], size > 0 {
            return size.formattedFileSize
        }
        return model.formattedSize
    }

    func select(_ model: SpeechModelInfo) {
        guard isDownloaded(model), !isActive(model) else { return }
        settings.sttEngine = model.engine
        if model.engine == .whisper {
            settings.sttModelId = model.id
        } else if let variant = ParakeetVariant(rawValue: model.id) {
            settings.parakeetVariant = variant
        }
        ModelWarmupCoordinator.shared.switchSpeechModel()
    }

    func download(_ model: SpeechModelInfo) {
        switch model.engine {
        case .whisper: whisper.downloadAndActivate(model.id)
        case .parakeet:
            if let variant = ParakeetVariant(rawValue: model.id) {
                parakeet.downloadAndActivate(variant)
            }
        }
    }

    func cancelDownload(of model: SpeechModelInfo) {
        switch model.engine {
        case .whisper: whisper.cancelDownload()
        case .parakeet: parakeet.cancelDownload()
        }
    }

    func delete(_ model: SpeechModelInfo) async {
        switch model.engine {
        case .whisper: await whisper.deleteModel(model.id)
        case .parakeet:
            if let variant = ParakeetVariant(rawValue: model.id) {
                await parakeet.deleteModel(variant)
            }
        }
    }

    func clearDownloadError() {
        whisper.downloadError = nil
        parakeet.downloadError = nil
    }
}
