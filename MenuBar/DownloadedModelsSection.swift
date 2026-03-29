import SwiftUI

struct DownloadedModelsSection: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @State private var modelToDeleteSTT: WhisperModelInfo?
    @State private var modelToDeleteLLM: DownloadedModel?

    var body: some View {
        let whisperDownloaded = WhisperModelManager.defaultModels.filter {
            pipeline.whisperModelManager.downloadedModelIds.contains($0.id)
        }
        let llmDownloaded = pipeline.downloadedModelsManager.downloadedModels
        let hasAny = !whisperDownloaded.isEmpty || !llmDownloaded.isEmpty

        if hasAny {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "section.downloaded", defaultValue: "Downloaded models"))
                    .font(.headline)

                VStack(spacing: 2) {
                    // Whisper models
                    ForEach(whisperDownloaded) { model in
                        Button {
                            pipeline.whisperModelManager.activeModelId = model.id
                            settings.sttModelId = model.id
                        } label: {
                            HStack {
                                Image(systemName: model.id == pipeline.whisperModelManager.activeModelId ? "circle.fill" : "circle")
                                    .foregroundStyle(model.id == pipeline.whisperModelManager.activeModelId ? Color("AccentColor") : .secondary)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(model.displayName)
                                        .font(.caption)
                                    Text("STT")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(model.formattedSize)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    modelToDeleteSTT = model
                                } label: {
                                    let isActive = model.id == pipeline.whisperModelManager.activeModelId
                                    Image(systemName: "trash")
                                        .foregroundStyle(isActive ? Color.secondary : Color.red)
                                        .font(.body)
                                }
                                .buttonStyle(.plain)
                                .disabled(model.id == pipeline.whisperModelManager.activeModelId)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }

                    // LLM models
                    ForEach(llmDownloaded) { model in
                        Button {
                            settings.llmModelId = model.id
                        } label: {
                            HStack {
                                Image(systemName: model.id == settings.llmModelId ? "circle.fill" : "circle")
                                    .foregroundStyle(model.id == settings.llmModelId ? Color("AccentColor") : .secondary)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(model.shortName)
                                        .font(.caption)
                                    Text("LLM")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(model.formattedSize)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    modelToDeleteLLM = model
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                        .font(.body)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                let totalDisk = pipeline.downloadedModelsManager.totalSizeOnDisk + pipeline.whisperModelManager.totalSizeOnDisk()
                if totalDisk > 0 {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundStyle(.secondary)
                        Text(String(localized: "section.downloaded.total", defaultValue: "Total on disk:"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: totalDisk, countStyle: .file))
                            .font(.caption.bold())
                    }
                }
            }
            .padding()
            .onAppear {
                pipeline.downloadedModelsManager.scanDownloadedModels()
            }
            .alert(
                String(localized: "alert.delete.stt.title", defaultValue: "Delete model?"),
                isPresented: Binding(get: { modelToDeleteSTT != nil }, set: { if !$0 { modelToDeleteSTT = nil } })
            ) {
                Button(String(localized: "alert.delete.confirm", defaultValue: "Delete"), role: .destructive) {
                    if let model = modelToDeleteSTT {
                        pipeline.whisperModelManager.deleteModel(model.id)
                    }
                    modelToDeleteSTT = nil
                }
                Button(String(localized: "alert.delete.cancel", defaultValue: "Cancel"), role: .cancel) {
                    modelToDeleteSTT = nil
                }
            } message: {
                if let model = modelToDeleteSTT {
                    Text(String(localized: "alert.delete.stt.message", defaultValue: "This will remove \(model.formattedSize) from disk. You will need to re-download the model."))
                }
            }
            .alert(
                String(localized: "alert.delete.llm.title", defaultValue: "Delete model?"),
                isPresented: Binding(get: { modelToDeleteLLM != nil }, set: { if !$0 { modelToDeleteLLM = nil } })
            ) {
                Button(String(localized: "alert.delete.confirm", defaultValue: "Delete"), role: .destructive) {
                    if let model = modelToDeleteLLM {
                        if model.id == settings.llmModelId {
                            Task { await LLMProcessor.shared.unloadModel() }
                        }
                        try? pipeline.downloadedModelsManager.deleteModel(model.id)
                    }
                    modelToDeleteLLM = nil
                }
                Button(String(localized: "alert.delete.cancel", defaultValue: "Cancel"), role: .cancel) {
                    modelToDeleteLLM = nil
                }
            } message: {
                if let model = modelToDeleteLLM {
                    Text(String(localized: "alert.delete.llm.message", defaultValue: "This will remove \(model.formattedSize) from disk. You will need to re-download the model."))
                }
            }
        }
    }
}
