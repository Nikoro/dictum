import SwiftUI

@MainActor
struct SetupSpeechRecognitionModelStep: View {
    let speechModels: SpeechModelCatalog
    let isUnlocked: Bool

    var body: some View {
        SetupStepContent(
            stepNumber: 2,
            title: String(localized: "setup.step2.title", defaultValue: "Speech recognition model"),
            isDone: speechModels.hasActiveModel
        ) {
            if isUnlocked {
                modelChoices
            } else {
                Text(String(localized: "setup.step1.locked", defaultValue: "Enable permissions above first."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
            }
        }
    }

    private var modelChoices: some View {
        VStack(spacing: 8) {
            ForEach(SpeechModelCatalog.models) { model in
                row(for: model)
            }
            if let error = speechModels.downloadError {
                ModelDownloadErrorView(errorMessage: error, onDismiss: speechModels.clearDownloadError)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func row(for model: SpeechModelInfo) -> some View {
        let isDownloading = speechModels.isDownloading(model)
        let isActive = speechModels.isActive(model)
        return SetupModelRow(
            name: model.displayName,
            description: isDownloading ? nil : model.description,
            formattedSize: speechModels.formattedSize(of: model),
            isRecommended: model.isRecommended,
            isChecked: isActive,
            isSelected: isActive,
            isDownloaded: speechModels.isDownloaded(model),
            isDownloading: isDownloading,
            downloadProgress: speechModels.downloadProgress(of: model),
            onSelect: { speechModels.select(model) },
            onDownload: { speechModels.download(model) },
            onCancel: { speechModels.cancelDownload(of: model) }
        )
    }
}
