import SwiftUI

@MainActor
struct SetupLLMProcessingStep: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @Binding var downloadedLLMId: String?
    let isUnlocked: Bool

    private var isDone: Bool {
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

                    Button(String(localized: "setup.step3.skip", defaultValue: "Skip \u{2014} use transcription only")) {
                        settings.llmCleanupEnabled = false
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
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
        Task {
            while pipeline.llmIsDownloading {
                try? await Task.sleep(for: .milliseconds(200))
            }
            if pipeline.llmDownloadError == nil {
                downloadedLLMId = modelId
                settings.llmCleanupEnabled = true
                UserDefaults.standard.set(modelId, forKey: UserDefaultsKey.llmDownloadedModelId.rawValue)
                pipeline.warmUpModels()
            }
        }
    }
}
