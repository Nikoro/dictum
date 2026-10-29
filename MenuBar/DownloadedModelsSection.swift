import SwiftUI

struct DownloadedModelsSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(WhisperModelStore.self) private var whisperModelStore
    @Environment(DownloadedLLMModelStore.self) private var downloadedLLMModelStore
    @Environment(LLMModelDownloadController.self) private var llmDownloads
    @State private var modelToDeleteSTT: WhisperModelInfo?
    @State private var modelToDeleteLLM: DownloadedLLMModel?

    private var whisperDownloadedModels: [WhisperModelInfo] {
        WhisperModelStore.defaultModels.filter {
            whisperModelStore.downloadedModelIds.contains($0.id)
        }
    }

    private var downloadedLLMModels: [DownloadedLLMModel] {
        downloadedLLMModelStore.downloadedModels
    }

    private var totalDiskUsage: Int64 {
        downloadedLLMModelStore.totalSizeOnDisk + whisperModelStore.cachedTotalSizeOnDisk
    }

    var body: some View {
        let hasAny = !whisperDownloadedModels.isEmpty || !downloadedLLMModels.isEmpty

        if hasAny {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "section.downloaded", defaultValue: "Downloaded models"))
                    .font(.headline)

                modelList

                if totalDiskUsage > 0 {
                    DownloadedModelsStorageSummary(totalDiskUsage: totalDiskUsage)
                }
            }
            .padding()
            .onAppear {
                downloadedLLMModelStore.scanDownloadedModels()
            }
            .whisperModelDeletionAlert(model: $modelToDeleteSTT) { model in
                Task { await whisperModelStore.deleteModel(model.id) }
            }
            .llmModelDeletionAlert(
                model: $modelToDeleteLLM,
                selectedModelId: settings.llmModelId,
                onUnloadSelectedModel: {
                    Task { await LLMProcessor.shared.unloadModel() }
                },
                onConfirmDeletion: { model in
                    do {
                        try downloadedLLMModelStore.deleteModel(model.id)
                    } catch {
                        dlog("[LLM] delete failed: \(error)")
                        llmDownloads.downloadError = error.localizedDescription
                    }
                }
            )
        }
    }

    private var modelList: some View {
        VStack(spacing: 2) {
            ForEach(whisperDownloadedModels) { model in
                DownloadedModelRow(
                    name: model.displayName,
                    kind: "STT",
                    formattedSize: model.formattedSize,
                    isSelected: model.id == whisperModelStore.activeModelId,
                    isDeletionBlocked: model.id == whisperModelStore.activeModelId,
                    onSelect: { selectWhisperModel(model.id) },
                    onDelete: { modelToDeleteSTT = model }
                )
            }
            ForEach(downloadedLLMModels) { model in
                DownloadedModelRow(
                    name: model.shortName,
                    kind: "LLM",
                    formattedSize: model.formattedSize,
                    isSelected: model.id == settings.llmModelId,
                    isDeletionBlocked: false,
                    onSelect: { settings.llmModelId = model.id },
                    onDelete: { modelToDeleteLLM = model }
                )
            }
        }
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func selectWhisperModel(_ modelId: String) {
        whisperModelStore.activeModelId = modelId
        settings.sttModelId = modelId
    }
}
