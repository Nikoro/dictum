import SwiftUI

struct DownloadedModelsSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(WhisperModelStore.self) private var whisperModelStore
    @Environment(ParakeetModelStore.self) private var parakeetModelStore
    @Environment(DownloadedLLMModelStore.self) private var downloadedLLMModelStore
    @Environment(LLMModelDownloadController.self) private var llmDownloads
    @State private var modelToDeleteSTT: SpeechModelInfo?
    @State private var modelToDeleteLLM: DownloadedLLMModel?

    private var speechModels: SpeechModelCatalog {
        SpeechModelCatalog(settings: settings, whisper: whisperModelStore, parakeet: parakeetModelStore)
    }

    private var downloadedLLMModels: [DownloadedLLMModel] {
        downloadedLLMModelStore.downloadedModels
    }

    private var totalDiskUsage: Int64 {
        downloadedLLMModelStore.totalSizeOnDisk + speechModels.totalSizeOnDisk
    }

    var body: some View {
        let hasAny = !speechModels.downloadedModels.isEmpty || !downloadedLLMModels.isEmpty

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
            .speechModelDeletionAlert(model: $modelToDeleteSTT, formattedSize: speechModels.formattedSize) { model in
                Task { await speechModels.delete(model) }
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
            ForEach(speechModels.downloadedModels) { model in
                DownloadedModelRow(
                    name: model.displayName,
                    kind: "STT",
                    formattedSize: speechModels.formattedSize(of: model),
                    isSelected: speechModels.isActive(model),
                    isDeletionBlocked: speechModels.isActive(model),
                    onSelect: { speechModels.select(model) },
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
}
