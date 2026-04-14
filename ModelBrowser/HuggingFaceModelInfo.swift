import Foundation

struct HuggingFaceModelFile: Codable {
    let rfilename: String
    let size: Int64?
}

struct HuggingFaceModelInfo: Codable, Identifiable {
    let id: String
    let downloads: Int?
    let tags: [String]?
    let siblings: [HuggingFaceModelFile]?

    var shortName: String {
        id.replacingOccurrences(of: "mlx-community/", with: "")
    }

    var totalSizeBytes: Int64 {
        siblings?.compactMap(\.size).reduce(0, +) ?? 0
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
}
