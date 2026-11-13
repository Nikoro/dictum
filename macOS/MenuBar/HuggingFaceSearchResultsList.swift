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
                ForEach(results, content: resultButton)
            }
        }
        .frame(maxHeight: 200)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
    }

    private func resultButton(for model: HuggingFaceModelInfo) -> some View {
        let isDownloaded = downloadedModelIds.contains(model.id)
        let isThisDownloading = downloadingModelId == model.id && isDownloading
        return Button {
            guard !isDownloading else { return }
            onDownloadModel(model.id)
        } label: {
            SearchResultRow(model: model, isDownloaded: isDownloaded, isDownloading: isThisDownloading)
        }
        .buttonStyle(.plain)
        .disabled(isDownloaded || isThisDownloading)
    }
}

private struct SearchResultRow: View {
    let model: HuggingFaceModelInfo
    let isDownloaded: Bool
    let isDownloading: Bool

    var body: some View {
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
            if isDownloading {
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
}
