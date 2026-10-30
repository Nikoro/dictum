import SwiftUI

@MainActor
struct DownloadedSTTModelsList: View {
    let speechModels: SpeechModelCatalog

    var body: some View {
        VStack(spacing: 2) {
            ForEach(speechModels.downloadedModels) { model in
                STTModelRow(
                    model: model,
                    formattedSize: speechModels.formattedSize(of: model),
                    isDownloaded: true,
                    isActive: speechModels.isActive(model),
                    isDownloading: false,
                    downloadProgress: 0
                ) {
                    speechModels.select(model)
                }
            }
        }
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

@MainActor
struct AvailableSTTModelsDisclosure: View {
    let speechModels: SpeechModelCatalog
    @Binding var isExpanded: Bool

    private var models: [SpeechModelInfo] {
        speechModels.availableModels
    }

    var body: some View {
        if !models.isEmpty {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(Color("AccentColor"))
                    Text(String(localized: "section.stt.more", defaultValue: "More models (\(models.count))"))
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
                modelList
            }
        }
    }

    private var modelList: some View {
        VStack(spacing: 2) {
            ForEach(models) { model in
                STTModelRow(
                    model: model,
                    formattedSize: speechModels.formattedSize(of: model),
                    isDownloaded: false,
                    isActive: false,
                    isDownloading: speechModels.isDownloading(model),
                    downloadProgress: speechModels.downloadProgress(of: model),
                    onSelect: {
                        if !speechModels.isDownloading(model) {
                            speechModels.download(model)
                        }
                    },
                    onCancel: { speechModels.cancelDownload(of: model) }
                )
            }
        }
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

@MainActor
struct STTModelRow: View {
    let model: SpeechModelInfo
    let formattedSize: String
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
                    Image(systemName: isActive ? "circle.fill" : "circle")
                        .foregroundStyle(isActive ? Color("AccentColor") : .secondary)
                        .font(.caption2)
                    nameAndDescription
                    Spacer()
                    Text(formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    downloadStatus
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

    private var nameAndDescription: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(model.displayName)
                .fontWeight(isActive ? .semibold : .regular)
            Text(model.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var downloadStatus: some View {
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
            .accessibilityLabel(String(localized: "a11y.cancelDownload", defaultValue: "Cancel download"))
        } else if !isDownloaded {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(Color("AccentColor"))
                .font(.body)
        }
    }
}
