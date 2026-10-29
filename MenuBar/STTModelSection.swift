import SwiftUI

struct STTModelSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(WhisperModelStore.self) private var whisperModelStore
    @State private var isExpanded = false

    private var downloadedModels: [WhisperModelInfo] {
        WhisperModelStore.defaultModels.filter {
            whisperModelStore.downloadedModelIds.contains($0.id)
        }
    }

    private var availableModels: [WhisperModelInfo] {
        WhisperModelStore.defaultModels.filter {
            !whisperModelStore.downloadedModelIds.contains($0.id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.stt", defaultValue: "STT Model"))
                .font(.headline)

            if !downloadedModels.isEmpty {
                DownloadedSTTModelsList(
                    models: downloadedModels,
                    activeModelId: whisperModelStore.activeModelId,
                    onSelectModel: selectDownloadedModel
                )
            }

            AvailableSTTModelsDisclosure(
                models: availableModels,
                downloadingModelId: whisperModelStore.downloadingModelId,
                downloadProgress: whisperModelStore.downloadProgress,
                isExpanded: $isExpanded,
                onDownloadModel: whisperModelStore.downloadAndActivate,
                onCancelDownload: whisperModelStore.cancelDownload
            )
        }
        .padding()
    }

    private func selectDownloadedModel(_ modelId: String) {
        whisperModelStore.activeModelId = modelId
        settings.sttModelId = modelId
    }
}
