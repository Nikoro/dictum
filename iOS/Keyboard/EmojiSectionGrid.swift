import SwiftUI

struct EmojiSectionGrid: View {
    let preferences: EmojiPreferences
    let palette: KeyboardPalette
    let categories: [String]
    var tablet = false
    var landscape = false
    @Binding var category: Int?
    let pick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 28) {
                section(-1, label: String(localized: "ios.emoji.frequent"), symbols: frequent)
                ForEach(categories.indices, id: \.self) { index in
                    section(index, label: categories[index], symbols: symbols(in: index))
                }
            }
            .padding(.horizontal, tablet ? 20 : 10)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $category, anchor: .leading)
        .scrollIndicators(.hidden)
    }

    private var frequent: [String] {
        QuickEmojiChoices.filling(preferences.frequent(limit: 48), limit: max(30, preferences.recents.count))
            .filter { EmojiCatalog.shared.entry(for: $0) != nil }
    }

    private func symbols(in category: Int) -> [String] {
        EmojiCatalog.shared.entries.filter { $0.category == category }.map { $0.symbol(tone: preferences.tone) }
    }

    private func section(_ id: Int, label: String, symbols: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: tablet ? 17 : 12, weight: .semibold))
                .foregroundStyle(palette.foreground.opacity(0.61))
                .lineLimit(1)
                .padding(.leading, 2)
                .frame(height: tablet ? 50 : 30)
            LazyHGrid(
                rows: rows,
                spacing: tablet ? 20 : 14
            ) {
                ForEach(symbols, id: \.self) { symbol in
                    emojiButton(symbol)
                }
            }
        }
        .id(id)
    }

    private var rows: [GridItem] {
        let height: CGFloat = tablet ? (landscape ? 52 : 44) : 32
        let spacing: CGFloat = tablet ? (landscape ? 42 : 32) : 6.5
        return Array(repeating: GridItem(.fixed(height), spacing: spacing), count: tablet ? 3 : 5)
    }

    private func emojiButton(_ symbol: String) -> some View {
        Button { pick(symbol) } label: {
            Text(symbol).font(.system(size: tablet ? 40 : 32)).frame(
                width: tablet ? 44 : 32,
                height: tablet ? 44 : 32
            )
        }
        .accessibilityLabel(EmojiCatalog.shared.entry(for: symbol)?.label ?? symbol)
        .contextMenu { variants(of: symbol) }
    }

    @ViewBuilder private func variants(of symbol: String) -> some View {
        if let entry = EmojiCatalog.shared.entry(for: symbol), !entry.variants.isEmpty {
            Button(String(localized: "ios.emoji.default_skin")) { pick(entry.symbol) }
            ForEach(entry.variants, id: \.self) { variant in
                Button(variant) { pick(variant) }
            }
        }
    }
}
