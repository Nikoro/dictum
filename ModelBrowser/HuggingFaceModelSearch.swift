import Foundation
import SwiftUI

@MainActor
final class HuggingFaceModelSearch: ObservableObject {
    static let shared = HuggingFaceModelSearch()
    @Published var searchQuery = ""
    @Published var searchResults: [HuggingFaceModelInfo] = []
    @Published var isSearching = false
    @Published var searchError: String?

    private var searchTask: Task<Void, Never>?
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

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
            searchError = nil
            defer { isSearching = false }

            let query = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "https://huggingface.co/api/models?author=mlx-community&search=\(query)&sort=downloads&direction=-1&limit=20&full=true"

            guard let url = URL(string: urlString) else { return }

            do {
                let (data, response) = try await Self.session.data(from: url)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    throw URLError(.badServerResponse)
                }
                let models = try JSONDecoder().decode([HuggingFaceModelInfo].self, from: data)

                guard !Task.isCancelled else { return }

                self.searchResults = models
            } catch {
                if !Task.isCancelled {
                    dlog("[HF] search error: \(error)")
                    searchError = error.localizedDescription
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
