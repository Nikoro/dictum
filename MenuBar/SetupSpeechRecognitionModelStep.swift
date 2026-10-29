import SwiftUI

@MainActor
struct SetupSpeechRecognitionModelStep: View {
    let whisperModelStore: WhisperModelStore
    @Binding var selectedModelId: String
    let isUnlocked: Bool

    var body: some View {
        SetupStepContent(
            stepNumber: 2,
            title: String(localized: "setup.step2.title", defaultValue: "Speech recognition model"),
            isDone: whisperModelStore.downloadedModelIds.contains(selectedModelId)
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
            ForEach(WhisperModelStore.defaultModels) { model in
                row(for: model)
            }
            if let error = whisperModelStore.downloadError {
                ModelDownloadErrorView(errorMessage: error, onDismiss: clearDownloadError)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func clearDownloadError() {
        whisperModelStore.downloadError = nil
    }

    private func row(for model: WhisperModelInfo) -> some View {
        let isDownloading = whisperModelStore.downloadingModelId == model.id
        return SetupModelRow(
            name: model.displayName,
            description: isDownloading ? nil : model.description,
            formattedSize: model.formattedSize,
            isRecommended: model.isRecommended,
            isChecked: selectedModelId == model.id,
            isSelected: selectedModelId == model.id,
            isDownloaded: whisperModelStore.downloadedModelIds.contains(model.id),
            isDownloading: isDownloading,
            downloadProgress: isDownloading ? whisperModelStore.downloadProgress : 0,
            onSelect: {
                selectedModelId = model.id
                whisperModelStore.activeModelId = model.id
            },
            onDownload: {
                selectedModelId = model.id
                whisperModelStore.downloadAndActivate(model.id)
            },
            onCancel: whisperModelStore.cancelDownload
        )
    }
}
