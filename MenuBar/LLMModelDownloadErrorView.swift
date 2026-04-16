import SwiftUI

@MainActor
struct LLMModelDownloadErrorView: View {
    let errorMessage: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
    }
}
