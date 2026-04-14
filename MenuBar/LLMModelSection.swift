import SwiftUI

@MainActor
struct LLMModelSection: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @ObservedObject private var modelSearch: HuggingFaceModelSearch

    init() {
        _modelSearch = ObservedObject(wrappedValue: HuggingFaceModelSearch.shared)
    }

    private var isDownloading: Bool { pipeline.llmIsDownloading }
    private var downloadingModelId: String? { pipeline.llmDownloadingModelId }
    private var downloadProgress: Double { pipeline.llmDownloadProgress }

    private var downloadedModels: [DownloadedLLMModel] {
        pipeline.downloadedLLMModelStore.downloadedModels
    }

    private var downloadedModelIds: Set<String> {
        Set(downloadedModels.map(\.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.llm", defaultValue: "LLM Model"))
                .font(.headline)

            if !downloadedModels.isEmpty {
                DownloadedLLMModelPicker(
                    models: downloadedModels,
                    selectedModelId: settings.llmModelId,
                    onSelectModel: selectDownloadedModel
                )
            }

            HuggingFaceSearchField(
                searchQuery: $modelSearch.searchQuery,
                isSearching: modelSearch.isSearching,
                onSearchChange: modelSearch.search,
                onClear: modelSearch.clearSearch
            )

            if !modelSearch.searchResults.isEmpty {
                HuggingFaceSearchResultsList(
                    results: modelSearch.searchResults,
                    downloadedModelIds: downloadedModelIds,
                    downloadingModelId: downloadingModelId,
                    isDownloading: isDownloading,
                    onDownloadModel: downloadModel
                )
            }

            if isDownloading, let modelId = downloadingModelId {
                LLMModelDownloadStatusView(
                    modelId: modelId,
                    progress: downloadProgress,
                    onCancel: cancelDownload
                )
            }

            if let error = pipeline.llmDownloadError {
                LLMModelDownloadErrorView(errorMessage: error) {
                    pipeline.llmDownloadError = nil
                }
            }

            GeneralPromptSection(hasDownloadedModels: !downloadedModels.isEmpty)
            AppPromptsSection(hasDownloadedModels: !downloadedModels.isEmpty)
        }
        .padding()
    }

    private func selectDownloadedModel(_ modelId: String) {
        settings.llmModelId = modelId
        pipeline.downloadedLLMModelStore.scanDownloadedModels()
    }

    private func downloadModel(_ modelId: String) {
        modelSearch.clearSearch()
        pipeline.downloadLLMModel(modelId)
    }

    private func cancelDownload() {
        pipeline.cancelLLMDownload()
    }
}
