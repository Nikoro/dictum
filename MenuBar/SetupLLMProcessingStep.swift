import SwiftUI

@MainActor
struct SetupLLMProcessingStep: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @Binding var downloadedLLMId: String?
    let isUnlocked: Bool
    @State private var isSkipped = false

    private var isDone: Bool {
        if isSkipped { return true }
        guard let downloadedLLMId else { return false }
        return pipeline.downloadedLLMModelStore.downloadedModels.contains { $0.id == downloadedLLMId }
    }

    var body: some View {
        SetupStepContent(
            stepNumber: 3,
            title: String(localized: "setup.step3.title", defaultValue: "LLM text processing (optional)"),
            isDone: isDone
        ) {
            if isUnlocked {
                VStack(spacing: 8) {
                    ForEach(setupLLMModelOptions) { model in
                        SetupLLMRow(
                            model: model,
                            isSelected: settings.llmModelId == model.id,
                            isDownloaded: downloadedLLMId == model.id,
                            isDownloading: pipeline.llmDownloadingModelId == model.id,
                            downloadProgress: pipeline.llmDownloadingModelId == model.id ? pipeline.llmDownloadProgress : 0,
                            onSelect: {
                                settings.llmModelId = model.id
                            },
                            onDownload: {
                                startDownload(for: model.id)
                            },
                            onCancel: {
                                pipeline.cancelLLMDownload()
                            }
                        )
                    }

                    if let error = pipeline.llmDownloadError {
                        LLMModelDownloadErrorView(errorMessage: error) {
                            pipeline.llmDownloadError = nil
                        }
                    }

                    Button(String(localized: "setup.step3.skip", defaultValue: "Skip \u{2014} use transcription only")) {
                        settings.llmCleanupEnabled = false
                        isSkipped = true
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .onChange(of: pipeline.llmIsDownloading) { _, isDownloading in
                    if !isDownloading { handleDownloadFinished() }
                }
            } else {
                Text(String(localized: "setup.step2.locked", defaultValue: "Download STT model first."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
            }
        }
    }

    private func startDownload(for modelId: String) {
        settings.llmModelId = modelId
        pipeline.downloadLLMModel(modelId)
    }

    private func handleDownloadFinished() {
        guard !pipeline.llmIsDownloading, pipeline.llmDownloadError == nil else { return }
        guard let modelId = settings.llmModelId as String?,
              pipeline.downloadedLLMModelStore.downloadedModels.contains(where: { $0.id == modelId }) else { return }
        downloadedLLMId = modelId
        settings.llmCleanupEnabled = true
        UserDefaults.standard.set(modelId, forKey: UserDefaultsKey.llmDownloadedModelId.rawValue)
        pipeline.warmUpModels()
    }
}
