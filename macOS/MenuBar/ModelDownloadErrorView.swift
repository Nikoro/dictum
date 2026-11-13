import SwiftUI

@MainActor
struct ModelDownloadErrorView: View {
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
            .accessibilityLabel(String(localized: "a11y.dismiss", defaultValue: "Dismiss"))
        }
    }
}
