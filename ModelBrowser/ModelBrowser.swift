import Foundation
import SwiftUI

struct HFSibling: Codable {
    let rfilename: String
    let size: Int64?
}

struct HFModelInfo: Codable, Identifiable {
    let id: String
    let downloads: Int?
    let tags: [String]?
    let siblings: [HFSibling]?

    var shortName: String {
        id.replacingOccurrences(of: "mlx-community/", with: "")
    }

    var totalSizeBytes: Int64 {
        siblings?.compactMap(\.size).reduce(0, +) ?? 0
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }

    var isRecommended: Bool {
        HFModelInfo.recommendedModelIds.contains(id)
    }

    /// Model IDs that appear at the top of search results with a "Recommended" badge.
    static let recommendedModelIds: Set<String> = [
        "mlx-community/gemma-4-e4b-it-4bit",
        "mlx-community/gemma-4-e2b-it-4bit",
    ]
}

@MainActor
final class ModelBrowser: ObservableObject {
    static let shared = ModelBrowser()
    @Published var searchQuery = ""
    @Published var searchResults: [HFModelInfo] = []
    @Published var isSearching = false

    private var searchTask: Task<Void, Never>?

    func search() {
        searchTask?.cancel()

        guard searchQuery.count >= 2 else {
            searchResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }

            isSearching = true
            defer { isSearching = false }

            let query = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "https://huggingface.co/api/models?author=mlx-community&search=\(query)&sort=downloads&direction=-1&limit=20&full=true"

            guard let url = URL(string: urlString) else { return }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let models = try JSONDecoder().decode([HFModelInfo].self, from: data)

                guard !Task.isCancelled else { return }

                // Sort recommended models to the top, preserve order within each group
                let recommended = models.filter { HFModelInfo.recommendedModelIds.contains($0.id) }
                let rest = models.filter { !HFModelInfo.recommendedModelIds.contains($0.id) }
                self.searchResults = recommended + rest
            } catch {
                if !Task.isCancelled {
                    print("HF API error: \(error)")
                }
            }
        }
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchTask?.cancel()
    }
}
