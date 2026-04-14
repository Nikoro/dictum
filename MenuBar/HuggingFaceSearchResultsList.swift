import SwiftUI

@MainActor
struct HuggingFaceSearchResultsList: View {
    let results: [HuggingFaceModelInfo]
    let downloadedModelIds: Set<String>
    let downloadingModelId: String?
    let isDownloading: Bool
    let onDownloadModel: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(results) { model in
                    let isDownloaded = downloadedModelIds.contains(model.id)
                    let isThisDownloading = downloadingModelId == model.id && isDownloading
                    Button {
                        guard !isDownloading else { return }
                        onDownloadModel(model.id)
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
}
