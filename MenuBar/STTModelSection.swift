import SwiftUI

struct STTModelSection: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @State private var isExpanded = false

    private var downloadedModels: [WhisperModelInfo] {
        WhisperModelManager.defaultModels.filter {
            pipeline.whisperModelManager.downloadedModelIds.contains($0.id)
        }
    }

    private var availableModels: [WhisperModelInfo] {
        WhisperModelManager.defaultModels.filter {
            !pipeline.whisperModelManager.downloadedModelIds.contains($0.id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.stt", defaultValue: "STT Model"))
                .font(.headline)

            // Downloaded models
            if !downloadedModels.isEmpty {
                VStack(spacing: 2) {
                    ForEach(downloadedModels) { model in
                        WhisperModelRow(
                            model: model,
                            isDownloaded: true,
                            isActive: pipeline.whisperModelManager.activeModelId == model.id,
                            isDownloading: false,
                            downloadProgress: 0
                        ) {
                            pipeline.whisperModelManager.activeModelId = model.id
                            settings.sttModelId = model.id
                        }
                    }
                }
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Expandable list of available models
            if !availableModels.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color("AccentColor"))
                        Text(String(localized: "section.stt.more", defaultValue: "More models (\(availableModels.count))"))
                            .font(.subheadline)
                            .foregroundStyle(Color("AccentColor"))
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 2) {
                        ForEach(availableModels) { model in
                            WhisperModelRow(
                                model: model,
                                isDownloaded: false,
                                isActive: false,
                                isDownloading: pipeline.whisperModelManager.downloadingModelId == model.id,
                                downloadProgress: pipeline.whisperModelManager.downloadingModelId == model.id ? pipeline.whisperModelManager.downloadProgress : 0
                            ) {
                                pipeline.whisperModelManager.downloadAndActivate(model.id)
                            } onCancel: {
                                pipeline.whisperModelManager.cancelDownload()
                            }
                        }
                    }
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
    }
}

private struct WhisperModelRow: View {
    let model: WhisperModelInfo
    let isDownloaded: Bool
    let isActive: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    var onCancel: (() -> Void)?

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                HStack {
                    if isActive {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(Color("AccentColor"))
                            .font(.caption2)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                            .font(.caption2)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.displayName)
                            .fontWeight(isActive ? .semibold : .regular)
                        Text(model.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(model.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isDownloading {
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                        Button {
                            onCancel?()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else if !isDownloaded {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color("AccentColor"))
                            .font(.body)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                if isDownloading {
                    ProgressView(value: downloadProgress)
                        .tint(Color("AccentColor"))
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
