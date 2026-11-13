import SwiftUI

@MainActor
struct DownloadedModelsStorageSummary: View {
    let totalDiskUsage: Int64

    var body: some View {
        HStack {
            Image(systemName: "internaldrive")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(String(localized: "section.downloaded.total", defaultValue: "Total on disk:"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(totalDiskUsage.formattedFileSize)
                .font(.caption.bold())
        }
    }
}
