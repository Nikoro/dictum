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
}

@MainActor
final class ModelBrowser: ObservableObject {
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

                self.searchResults = models.filter { model in
                    let tags = model.tags ?? []
                    return tags.contains("text-generation") || tags.isEmpty
                }
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
