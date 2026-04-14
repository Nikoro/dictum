import SwiftUI

@MainActor
struct LLMModelSection: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @ObservedObject private var browser: ModelBrowser

    init() {
        _browser = ObservedObject(wrappedValue: ModelBrowser.shared)
    }

    private var isDownloading: Bool { pipeline.llmIsDownloading }
    private var downloadingModelId: String? { pipeline.llmDownloadingModelId }
    private var downloadProgress: Double { pipeline.llmDownloadProgress }

    private var downloadedModels: [DownloadedModel] {
        pipeline.downloadedModelsManager.downloadedModels
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.llm", defaultValue: "LLM Model"))
                .font(.headline)

            // Downloaded models list (like STT)
            if !downloadedModels.isEmpty {
                VStack(spacing: 2) {
                    ForEach(downloadedModels) { model in
                        Button {
                            settings.llmModelId = model.id
                            pipeline.downloadedModelsManager.scanDownloadedModels()
                        } label: {
                            HStack {
                                Image(systemName: model.id == settings.llmModelId ? "circle.fill" : "circle")
                                    .foregroundStyle(model.id == settings.llmModelId ? Color("AccentColor") : .secondary)
                                    .font(.caption2)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(model.shortName)
                                        .fontWeight(model.id == settings.llmModelId ? .semibold : .regular)
                                    Text(model.formattedSize)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "section.llm.search", defaultValue: "Search models (e.g. qwen, gemma, llama)..."), text: $browser.searchQuery)
                    .textFieldStyle(.plain)
                    .onChange(of: browser.searchQuery) { _, _ in
                        browser.search()
                    }
                if browser.isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                if !browser.searchQuery.isEmpty {
                    Button {
                        browser.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Search results
            if !browser.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(browser.searchResults) { model in
                            let isDownloaded = downloadedModels.contains { $0.id == model.id }
                            let isThisDownloading = downloadingModelId == model.id && isDownloading
                            Button {
                                guard !isDownloading else { return }
                                downloadModel(model.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.shortName)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(isDownloaded ? .semibold : .regular)
                                        if model.totalSizeBytes > 0 {
                                            Text(model.formattedSize)
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    Spacer()
                                    if isThisDownloading {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    } else if isDownloaded {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(isDownloaded || isThisDownloading)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
            }

            // Download progress
            if isDownloading, let modelId = downloadingModelId {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text(String(localized: "section.llm.downloading", defaultValue: "Downloading \(modelId.replacingOccurrences(of: "mlx-community/", with: ""))..."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button {
                            cancelDownload()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    ProgressView(value: downloadProgress)
                        .tint(Color("AccentColor"))
                }
            }

            if let error = pipeline.llmDownloadError {
                HStack {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button {
                        pipeline.llmDownloadError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Prompts
            GeneralPromptSection(hasDownloadedModels: !downloadedModels.isEmpty)
            AppPromptsSection(hasDownloadedModels: !downloadedModels.isEmpty)
        }
        .padding()
    }

    private func downloadModel(_ modelId: String) {
        browser.clearSearch()
        pipeline.downloadLLMModel(modelId)
    }

    private func cancelDownload() {
        pipeline.cancelLLMDownload()
    }
}
