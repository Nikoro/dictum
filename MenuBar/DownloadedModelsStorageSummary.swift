import SwiftUI

@MainActor
struct DownloadedModelsStorageSummary: View {
    let totalDiskUsage: Int64

    var body: some View {
        HStack {
            Image(systemName: "internaldrive")
                .foregroundStyle(.secondary)
            Text(String(localized: "section.downloaded.total", defaultValue: "Total on disk:"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: totalDiskUsage, countStyle: .file))
                .font(.caption.bold())
        }
    }
}
