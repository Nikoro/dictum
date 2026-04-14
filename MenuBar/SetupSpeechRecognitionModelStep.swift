import SwiftUI

@MainActor
struct SetupSpeechRecognitionModelStep: View {
    @ObservedObject var whisperModelStore: WhisperModelStore
    @Binding var selectedModelId: String
    let isUnlocked: Bool

    var body: some View {
        SetupStepContent(
            stepNumber: 2,
            title: String(localized: "setup.step2.title", defaultValue: "Speech recognition model"),
            isDone: whisperModelStore.downloadedModelIds.contains(selectedModelId)
        ) {
            if isUnlocked {
                VStack(spacing: 8) {
                    ForEach(WhisperModelStore.defaultModels) { model in
                        SetupModelRow(
                            model: model,
                            isSelected: selectedModelId == model.id,
                            isDownloaded: whisperModelStore.downloadedModelIds.contains(model.id),
                            isDownloading: whisperModelStore.downloadingModelId == model.id,
                            downloadProgress: whisperModelStore.downloadingModelId == model.id ? whisperModelStore.downloadProgress : 0,
                            onSelect: {
                                selectedModelId = model.id
                                whisperModelStore.activeModelId = model.id
                            },
                            onDownload: {
                                selectedModelId = model.id
                                whisperModelStore.downloadAndActivate(model.id)
                            },
                            onCancel: {
                                whisperModelStore.cancelDownload()
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            } else {
                Text(String(localized: "setup.step1.locked", defaultValue: "Enable permissions above first."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
            }
        }
    }
}
