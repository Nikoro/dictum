import SwiftUI
import UIKit

struct EmojiBrowserView: View {
    @Bindable var model: KeyboardModel
    let palette: KeyboardPalette
    let insert: (String) -> Void
    @State private var category: Int? = -1

    private let catalog = EmojiCatalog.shared

    var body: some View {
        VStack(spacing: 0) {
            if !model.tabletLayout || model.emojiSearchActive {
                searchBar
            }
            if model.emojiSearchActive {
                searchResults
            } else {
                EmojiSectionGrid(
                    preferences: model.emojiPreferences,
                    palette: palette,
                    categories: categories,
                    tablet: model.tabletLayout,
                    landscape: model.landscapeLayout,
                    category: $category,
                    pick: pick
                )
                categoryBar
            }
        }
        .foregroundStyle(palette.foreground)
        .background(Color.black.opacity(0.01))
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            searchButton
            if model.emojiSearchActive {
                Button {
                    model.emojiQuery = ""
                } label: { Image(systemName: "xmark.circle.fill") }
                    .accessibilityLabel(String(localized: "a11y.clearSearch"))
                Button(String(localized: "ios.emoji.done")) { model.emojiSearchActive = false }
                    .font(.system(size: 13))
            }
        }
        .padding(.horizontal, 9)
        .padding(.top, 10)
        .padding(.bottom, 3)
        .frame(height: 53)
    }

    private var searchButton: some View {
        Button {
            model.emojiSearchActive = true
            model.numbers = false
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.foreground.opacity(0.455))
                Text(model.emojiQuery.isEmpty ? String(localized: "ios.emoji.search") : model.emojiQuery)
                    .lineLimit(1)
                    .foregroundStyle(palette.foreground.opacity(model.emojiQuery.isEmpty ? 0.455 : 1))
                if model.emojiSearchActive {
                    Rectangle().fill(.tint).frame(width: 1, height: 14)
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 17))
            .padding(.horizontal, 18)
            .frame(height: 40)
            .background(
                palette.dark ? Color(red: 52 / 255, green: 52 / 255, blue: 54 / 255) : .white,
                in: .rect(cornerRadius: 13)
            )
        }
        .accessibilityLabel(String(localized: "ios.emoji.search"))
        .accessibilityValue(model.emojiQuery)
    }

    private var searchResults: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: [GridItem(.fixed(40)), GridItem(.fixed(40))], spacing: 3) {
                ForEach(searchChoices, id: \.self) { symbol in emojiKey(symbol).frame(width: 42) }
            }
            .padding(.horizontal, 6)
        }
        .scrollIndicators(.hidden)
        .overlay {
            if searchChoices.isEmpty {
                Text(String(localized: model.emojiQuery.isEmpty ? "ios.emoji.search" : "ios.emoji.no_results"))
                    .font(.footnote).foregroundStyle(palette.hint)
            }
        }
    }

    private func emojiKey(_ symbol: String) -> some View {
        Button { pick(symbol) } label: {
            Text(symbol).font(.system(size: 29)).frame(maxWidth: .infinity).frame(height: 38)
                .contentShape(.rect)
        }
        .accessibilityLabel(catalog.entry(for: symbol)?.label ?? symbol)
        .accessibilityHint(String(localized: "ios.emoji.skin"))
        .contextMenu {
            if let entry = catalog.entry(for: symbol), !entry.variants.isEmpty {
                ForEach([entry.symbol] + entry.variants, id: \.self) { variant in
                    Button(variant) { pick(variant) }
                }
            }
        }
    }

    private var categoryBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                categoryLeading
                categoryStrip(width: model.tabletLayout ? 54 : (geometry.size.width - 111.75) / 9)
                    .frame(width: model.tabletLayout ? 494.666 : nil)
                if model.tabletLayout {
                    Spacer(minLength: 0)
                }
                KeyboardDeleteKey(model: model, palette: palette, filled: false, foregroundOpacity: 0.72)
                    .frame(width: 49.333, height: 40)
                if model.tabletLayout {
                    Button(action: model.dismissKeyboard) { Image(systemName: "keyboard.chevron.compact.down") }
                        .accessibilityLabel(String(localized: "ios.keyboard.dismiss"))
                        .frame(width: 80, height: 44)
                }
            }
            .frame(height: model.tabletLayout ? 64 : 44)
        }
        .frame(height: model.tabletLayout ? 64 : 44)
    }

    @ViewBuilder
    private var categoryLeading: some View {
        Button("ABC") {
            model.emoji = false
            model.emojiSearchActive = false
            model.numbers = false
        }
        .font(.system(size: 19))
        .foregroundStyle(palette.foreground.opacity(0.85))
        .tracking(model.tabletLayout ? 3 : 0)
        .frame(width: model.tabletLayout ? 70 : 51.333, height: 44)
        if model.tabletLayout {
            Button { model.emojiSearchActive = true } label: {
                Image(systemName: "magnifyingglass").frame(width: 42, height: 44).contentShape(.rect)
            }
            .accessibilityLabel(String(localized: "ios.emoji.search"))
        }
    }

    private func categoryStrip(width: CGFloat) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                categoryButton(-1, width: width)
                ForEach(categories.indices, id: \.self) { index in
                    categoryButton(index, width: width)
                }
            }
            .padding(.horizontal, 4.333)
        }
        .scrollIndicators(.hidden)
    }

    private func categoryButton(_ value: Int, width: CGFloat) -> some View {
        Button {
            category = value
            model.emojiQuery = ""
        } label: {
            Image("KeyboardCategory\(value + 1)")
                .resizable()
                .renderingMode(.template)
                .frame(width: categoryIconSize, height: categoryIconSize)
                .foregroundStyle(palette.foreground.opacity(category == value ? 0.47 : 0.275))
                .frame(width: width, height: 40)
                .background {
                    if category == value {
                        Circle().fill(palette.foreground.opacity(0.06))
                            .frame(width: categorySelectionSize, height: categorySelectionSize)
                    }
                }
        }
        .accessibilityLabel(value == -1 ? String(localized: "ios.emoji.frequent") : categories[value])
        .accessibilityAddTraits(category == value ? .isSelected : [])
    }

    private var categoryIconSize: CGFloat {
        model.tabletLayout ? 40 : 32
    }

    private var categorySelectionSize: CGFloat {
        model.tabletLayout ? 44 : 31
    }

    private func pick(_ symbol: String) {
        UIDevice.current.playInputClick()
        insert(symbol)
        model.emojiPreferences.record(symbol)
    }

    private var searchChoices: [String] {
        catalog.search(model.emojiQuery).map { $0.symbol(tone: model.emojiPreferences.tone) }
    }
}

extension EmojiBrowserView {
    private var categories: [String] {
        [
            String(localized: "ios.emoji.people"),
            String(localized: "ios.emoji.nature"),
            String(localized: "ios.emoji.food"),
            String(localized: "ios.emoji.activity"),
            String(localized: "ios.emoji.travel"),
            String(localized: "ios.emoji.objects"),
            String(localized: "ios.emoji.symbols"),
            String(localized: "ios.emoji.flags")
        ]
    }
}
