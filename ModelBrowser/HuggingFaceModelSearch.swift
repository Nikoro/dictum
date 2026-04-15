import Foundation
import SwiftUI

@MainActor
final class HuggingFaceModelSearch: ObservableObject {
    static let shared = HuggingFaceModelSearch()
    @Published var searchQuery = ""
    @Published var searchResults: [HuggingFaceModelInfo] = []
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
                let models = try JSONDecoder().decode([HuggingFaceModelInfo].self, from: data)

                guard !Task.isCancelled else { return }

                self.searchResults = models
            } catch {
                if !Task.isCancelled {
                    dlog("[HF] search error: \(error)")
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
