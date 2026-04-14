import SwiftUI

@MainActor
struct HuggingFaceSearchField: View {
    @Binding var searchQuery: String
    let isSearching: Bool
    let onSearchChange: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                String(localized: "section.llm.search", defaultValue: "Search models (e.g. qwen, gemma, llama)..."),
                text: $searchQuery
            )
            .textFieldStyle(.plain)
            .onChange(of: searchQuery) { _, _ in
                onSearchChange()
            }

            if isSearching {
                ProgressView()
                    .scaleEffect(0.7)
            }

            if !searchQuery.isEmpty {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
