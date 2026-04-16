import SwiftUI

struct DownloadedModelsSection: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @State private var modelToDeleteSTT: WhisperModelInfo?
    @State private var modelToDeleteLLM: DownloadedLLMModel?

    private var whisperDownloadedModels: [WhisperModelInfo] {
        WhisperModelStore.defaultModels.filter {
            pipeline.whisperModelStore.downloadedModelIds.contains($0.id)
        }
    }

    private var downloadedLLMModels: [DownloadedLLMModel] {
        pipeline.downloadedLLMModelStore.downloadedModels
    }

    private var totalDiskUsage: Int64 {
        pipeline.downloadedLLMModelStore.totalSizeOnDisk + pipeline.whisperModelStore.cachedTotalSizeOnDisk
    }

    var body: some View {
        let hasAny = !whisperDownloadedModels.isEmpty || !downloadedLLMModels.isEmpty

        if hasAny {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "section.downloaded", defaultValue: "Downloaded models"))
                    .font(.headline)

                VStack(spacing: 2) {
                    DownloadedWhisperModelsList(
                        models: whisperDownloadedModels,
                        activeModelId: pipeline.whisperModelStore.activeModelId,
                        onSelectModel: selectWhisperModel,
                        onDeleteModel: requestWhisperModelDeletion
                    )
                    DownloadedLLMModelsList(
                        models: downloadedLLMModels,
                        selectedModelId: settings.llmModelId,
                        onSelectModel: selectLLMModel,
                        onDeleteModel: requestLLMModelDeletion
                    )
                }
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if totalDiskUsage > 0 {
                    DownloadedModelsStorageSummary(totalDiskUsage: totalDiskUsage)
                }
            }
            .padding()
            .onAppear {
                pipeline.downloadedLLMModelStore.scanDownloadedModels()
            }
            .whisperModelDeletionAlert(model: $modelToDeleteSTT) { model in
                Task { await pipeline.whisperModelStore.deleteModel(model.id) }
            }
            .llmModelDeletionAlert(
                model: $modelToDeleteLLM,
                selectedModelId: settings.llmModelId,
                onUnloadSelectedModel: {
                    Task { await LLMProcessor.shared.unloadModel() }
                },
                onConfirmDeletion: { model in
                    do {
                        try pipeline.downloadedLLMModelStore.deleteModel(model.id)
                    } catch {
                        dlog("[LLM] delete failed: \(error)")
                        pipeline.llmDownloadError = error.localizedDescription
                    }
                }
            )
        }
    }

    private func selectWhisperModel(_ modelId: String) {
        pipeline.whisperModelStore.activeModelId = modelId
        settings.sttModelId = modelId
    }

    private func requestWhisperModelDeletion(_ model: WhisperModelInfo) {
        modelToDeleteSTT = model
    }

    private func selectLLMModel(_ modelId: String) {
        settings.llmModelId = modelId
    }

    private func requestLLMModelDeletion(_ model: DownloadedLLMModel) {
        modelToDeleteLLM = model
    }
}
