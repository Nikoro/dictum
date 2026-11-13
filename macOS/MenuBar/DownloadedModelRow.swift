import SwiftUI

@MainActor
struct DownloadedModelRow: View {
    let name: String
    let kind: String
    let formattedSize: String
    let isSelected: Bool
    let isDeletionBlocked: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    var speechModel: SpeechModelInfo?

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isSelected ? "circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color("AccentColor") : .secondary)
                    .font(.caption2)
                titleAndDescription
                Spacer()
                Text(formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                deleteButton
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var titleAndDescription: some View {
        if let speechModel {
            SpeechModelDetails(model: speechModel, isSelected: isSelected)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                Text(kind)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .foregroundStyle(isDeletionBlocked ? Color.secondary : Color.red)
                .font(.body)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "a11y.delete", defaultValue: "Delete"))
        .disabled(isDeletionBlocked)
        .help(isDeletionBlocked
            ? String(localized: "help.switchModelFirst", defaultValue: "Switch to another model first to delete this one")
            : "")
    }
}
