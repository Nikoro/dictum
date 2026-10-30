import SwiftUI

@MainActor
struct SetupModelRow: View {
    let name: String
    let description: String?
    let formattedSize: String
    let isRecommended: Bool
    let isChecked: Bool
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Button(action: activate) {
            rowContent
                .background(
                    isSelected ? Color("AccentColor").opacity(0.08) : Color(nsColor: .quaternarySystemFill),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color("AccentColor").opacity(0.3) : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? .green : .secondary)
                    .font(.body)
                titleAndDescription
                Spacer()
                Text(formattedSize)
                    .font(.caption)
                    .foregroundStyle(.orange)
                downloadStatus
            }
            .padding(10)

            if isDownloading {
                ProgressView(value: downloadProgress)
                    .tint(Color("AccentColor"))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
    }

    private func activate() {
        if isDownloaded {
            onSelect()
        } else if !isDownloading {
            onDownload()
        }
    }

    private var titleAndDescription: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                if isRecommended {
                    RecommendedBadge()
                }
            }
            if let description {
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var downloadStatus: some View {
        if isDownloading {
            Text("\(Int(downloadProgress * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "a11y.cancelDownload", defaultValue: "Cancel download"))
        } else if isDownloaded {
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
                .font(.caption)
        } else {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(Color("AccentColor"))
                .font(.body)
        }
    }
}

private struct RecommendedBadge: View {
    var body: some View {
        Text(String(localized: "setup.recommended", defaultValue: "Recommended"))
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color("AccentColor"), in: Capsule())
    }
}
