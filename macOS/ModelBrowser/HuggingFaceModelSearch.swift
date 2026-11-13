import Foundation
import SwiftUI

@MainActor
@Observable
final class HuggingFaceModelSearch {
    static let shared = HuggingFaceModelSearch()
    var searchQuery = ""
    var searchResults: [HuggingFaceModelInfo] = []
    var isSearching = false
    var searchError: String?

    @ObservationIgnored private var searchTask: Task<Void, Never>?
    private static let typingDebounce: Duration = .milliseconds(300)
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

        let query = searchQuery
        searchTask = Task {
            try? await Task.sleep(for: Self.typingDebounce)
            guard !Task.isCancelled else { return }

            isSearching = true
            searchError = nil
            defer { isSearching = false }

            do {
                let models = try await Self.fetchMostDownloadedMLXModels(matching: query)
                guard !Task.isCancelled else { return }
                searchResults = models
            } catch {
                if !Task.isCancelled {
                    dlog("[HF] search error: \(error)")
                    searchError = error.localizedDescription
                }
            }
        }
    }

    private static func fetchMostDownloadedMLXModels(matching query: String) async throws -> [HuggingFaceModelInfo] {
        var components = URLComponents(string: "https://huggingface.co/api/models")
        components?.queryItems = [
            URLQueryItem(name: "author", value: "mlx-community"),
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "full", value: "true")
        ]
        guard let url = components?.url else { throw URLError(.badURL) }

        let (data, response) = try await session.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([HuggingFaceModelInfo].self, from: data)
    }

    func clearSearch() {
        searchQuery = ""
        searchResults = []
        searchTask?.cancel()
    }
}
