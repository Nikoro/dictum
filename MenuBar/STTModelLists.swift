import SwiftUI

@MainActor
struct DownloadedSTTModelsList: View {
    let models: [WhisperModelInfo]
    let activeModelId: String
    let onSelectModel: (String) -> Void

    var body: some View {
        VStack(spacing: 2) {
            ForEach(models) { model in
                STTModelRow(
                    model: model,
                    isDownloaded: true,
                    isActive: activeModelId == model.id,
                    isDownloading: false,
                    downloadProgress: 0,
                    onSelect: {
                        onSelectModel(model.id)
                    }
                )
            }
        }
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

@MainActor
struct AvailableSTTModelsDisclosure: View {
    let models: [WhisperModelInfo]
    let downloadingModelId: String?
    let downloadProgress: Double
    @Binding var isExpanded: Bool
    let onDownloadModel: (String) -> Void
    let onCancelDownload: () -> Void

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
                VStack(spacing: 2) {
                    ForEach(models) { model in
                        STTModelRow(
                            model: model,
                            isDownloaded: false,
                            isActive: false,
                            isDownloading: downloadingModelId == model.id,
                            downloadProgress: downloadingModelId == model.id ? downloadProgress : 0,
                            onSelect: {
                                onDownloadModel(model.id)
                            },
                            onCancel: onCancelDownload
                        )
                    }
                }
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

@MainActor
struct STTModelRow: View {
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
                    Image(systemName: isActive ? "circle.fill" : "circle")
                        .foregroundStyle(isActive ? Color("AccentColor") : .secondary)
                        .font(.caption2)

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
