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

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isSelected ? "circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color("AccentColor") : .secondary)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.caption)
                    Text(kind)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                deleteButton
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
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
