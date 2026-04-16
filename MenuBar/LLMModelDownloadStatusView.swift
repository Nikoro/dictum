import SwiftUI

@MainActor
struct LLMModelDownloadStatusView: View {
    let modelId: String
    let progress: Double
    let onCancel: () -> Void

    var body: some View {
        let shortModelId = ModelConstants.shortModelName(modelId)

        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text(
                    String(
                        localized: "section.llm.downloading",
                        defaultValue: "Downloading \(shortModelId)..."
                    )
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button(action: {
                    onCancel()
                }, label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                })
                .buttonStyle(.plain)
            }
            ProgressView(value: progress)
                .tint(Color("AccentColor"))
        }
    }
}
