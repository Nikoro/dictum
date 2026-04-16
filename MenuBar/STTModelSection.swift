import SwiftUI

struct STTModelSection: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @State private var isExpanded = false

    private var downloadedModels: [WhisperModelInfo] {
        WhisperModelStore.defaultModels.filter {
            pipeline.whisperModelStore.downloadedModelIds.contains($0.id)
        }
    }

    private var availableModels: [WhisperModelInfo] {
        WhisperModelStore.defaultModels.filter {
            !pipeline.whisperModelStore.downloadedModelIds.contains($0.id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.stt", defaultValue: "STT Model"))
                .font(.headline)

            if !downloadedModels.isEmpty {
                DownloadedSTTModelsList(
                    models: downloadedModels,
                    activeModelId: pipeline.whisperModelStore.activeModelId,
                    onSelectModel: selectDownloadedModel
                )
            }

            AvailableSTTModelsDisclosure(
                models: availableModels,
                downloadingModelId: pipeline.whisperModelStore.downloadingModelId,
                downloadProgress: pipeline.whisperModelStore.downloadProgress,
                isExpanded: $isExpanded,
                onDownloadModel: pipeline.whisperModelStore.downloadAndActivate,
                onCancelDownload: pipeline.whisperModelStore.cancelDownload
            )
        }
        .padding()
    }

    private func selectDownloadedModel(_ modelId: String) {
        pipeline.whisperModelStore.activeModelId = modelId
        settings.sttModelId = modelId
    }
}
