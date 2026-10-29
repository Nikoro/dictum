import SwiftUI

@MainActor
struct LLMModelSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DownloadedLLMModelStore.self) private var downloadedLLMModelStore
    @Environment(LLMModelDownloadController.self) private var llmDownloads
    @Environment(HuggingFaceModelSearch.self) private var modelSearch

    private var isDownloading: Bool {
        llmDownloads.isDownloading
    }

    private var downloadingModelId: String? {
        llmDownloads.downloadingModelId
    }

    private var downloadProgress: Double {
        llmDownloads.downloadProgress
    }

    private var downloadedModels: [DownloadedLLMModel] {
        downloadedLLMModelStore.downloadedModels
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

            modelSearchControls
            downloadStatus
            InstructionsSection(hasDownloadedModels: !downloadedModels.isEmpty)
        }
        .padding()
    }

    @ViewBuilder
    private var modelSearchControls: some View {
        HuggingFaceSearchField(
            searchQuery: Bindable(modelSearch).searchQuery,
            isSearching: modelSearch.isSearching,
            onSearchChange: modelSearch.search,
            onClear: modelSearch.clearSearch
        )

        if modelSearch.searchQuery.count == 1 {
            Text(String(localized: "search.minChars", defaultValue: "Type at least 2 characters"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let searchError = modelSearch.searchError {
            Text(searchError)
                .font(.caption)
                .foregroundStyle(.red)
        }

        if !modelSearch.searchResults.isEmpty {
            HuggingFaceSearchResultsList(
                results: modelSearch.searchResults,
                downloadedModelIds: downloadedModelIds,
                downloadingModelId: downloadingModelId,
                isDownloading: isDownloading,
                onDownloadModel: downloadModel
            )
        }
    }

    @ViewBuilder
    private var downloadStatus: some View {
        if isDownloading, let modelId = downloadingModelId {
            LLMModelDownloadStatusView(modelId: modelId, progress: downloadProgress, onCancel: cancelDownload)
        }

        if let error = llmDownloads.downloadError {
            ModelDownloadErrorView(errorMessage: error) {
                llmDownloads.downloadError = nil
            }
        }
    }

    private func selectDownloadedModel(_ modelId: String) {
        settings.llmModelId = modelId
        downloadedLLMModelStore.scanDownloadedModels()
    }

    private func downloadModel(_ modelId: String) {
        modelSearch.clearSearch()
        llmDownloads.downloadModel(modelId)
    }

    private func cancelDownload() {
        llmDownloads.cancelDownload()
    }
}
