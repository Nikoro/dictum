import SwiftUI

@MainActor
struct SetupLLMProcessingStep: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DownloadedLLMModelStore.self) private var downloadedLLMModelStore
    @Environment(LLMModelDownloadController.self) private var llmDownloads
    @Binding var downloadedLLMId: String?
    let isUnlocked: Bool
    @State private var isSkipped = false

    private var isDone: Bool {
        if isSkipped {
            return true
        }
        guard let downloadedLLMId else { return false }
        return downloadedLLMModelStore.downloadedModels.contains { $0.id == downloadedLLMId }
    }

    var body: some View {
        SetupStepContent(
            stepNumber: 3,
            title: String(localized: "setup.step3.title", defaultValue: "LLM text processing (optional)"),
            isDone: isDone
        ) {
            if isUnlocked {
                modelChoices
            } else {
                Text(String(localized: "setup.step2.locked", defaultValue: "Download STT model first."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
            }
        }
    }

    private var modelChoices: some View {
        VStack(spacing: 8) {
            ForEach(setupLLMModelOptions) { model in
                row(for: model)
            }

            if let error = llmDownloads.downloadError {
                ModelDownloadErrorView(errorMessage: error) {
                    llmDownloads.downloadError = nil
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
        .onChange(of: llmDownloads.isDownloading) { _, isDownloading in
            if !isDownloading {
                handleDownloadFinished()
            }
        }
    }

    private func row(for model: LLMModelOption) -> some View {
        let isDownloading = llmDownloads.downloadingModelId == model.id
        let isDownloaded = downloadedLLMId == model.id
        let isSelected = settings.llmModelId == model.id
        return SetupModelRow(
            name: model.displayName,
            description: model.description,
            formattedSize: model.sizeGB,
            isRecommended: model.recommended,
            isChecked: isSelected && isDownloaded,
            isSelected: isSelected,
            isDownloaded: isDownloaded,
            isDownloading: isDownloading,
            downloadProgress: isDownloading ? llmDownloads.downloadProgress : 0,
            onSelect: { settings.llmModelId = model.id },
            onDownload: { startDownload(for: model.id) },
            onCancel: llmDownloads.cancelDownload
        )
    }

    private func startDownload(for modelId: String) {
        settings.llmModelId = modelId
        llmDownloads.downloadModel(modelId)
    }

    private func handleDownloadFinished() {
        let modelId = settings.llmModelId
        guard !llmDownloads.isDownloading, llmDownloads.downloadError == nil,
              downloadedLLMModelStore.downloadedModels.contains(where: { $0.id == modelId }) else { return }
        downloadedLLMId = modelId
        settings.llmCleanupEnabled = true
        UserDefaults.standard.set(modelId, forKey: UserDefaultsKey.llmDownloadedModelId.rawValue)
        ModelWarmupCoordinator.shared.warmUpModels()
    }
}
