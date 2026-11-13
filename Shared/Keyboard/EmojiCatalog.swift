import Foundation

struct EmojiEntry: Decodable, Identifiable, Sendable {
    let symbol: String
    let category: Int
    let localizationKey: String
    let variants: [String]

    var id: String {
        symbol
    }

    func symbol(tone: Int) -> String {
        guard tone > 0, variants.indices.contains(tone - 1) else { return symbol }
        return variants[tone - 1]
    }

    var label: String {
        String(localized: String.LocalizationValue(localizationKey)).components(separatedBy: "\n")[0]
    }
}

struct EmojiCatalog: Sendable {
    static let shared: EmojiCatalog = {
        guard let url = Bundle.main.url(forResource: "EmojiCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url), let catalog = try? EmojiCatalog(data: data)
        else { return EmojiCatalog(entries: []) }
        return catalog
    }()

    let entries: [EmojiEntry]
    private let searchIndex: [String]
    private let symbolIndex: [String: Int]

    init(data: Data) throws {
        try self.init(entries: JSONDecoder().decode([EmojiEntry].self, from: data))
    }

    init(entries: [EmojiEntry]) {
        self.entries = entries
        let bundles = ["en", "pl"].compactMap { Bundle.main.url(forResource: $0, withExtension: "lproj") }
            .compactMap(Bundle.init(url:))
        searchIndex = entries.map { entry in
            let names = bundles.map { $0.localizedString(forKey: entry.localizationKey, value: nil, table: nil) }
            return Self.normalize(([entry.symbol] + names).joined(separator: " "))
        }
        var indices: [String: Int] = [:]
        for (index, entry) in entries.enumerated() {
            indices[entry.symbol] = index
            for variant in entry.variants {
                indices[variant] = index
            }
        }
        symbolIndex = indices
    }

    func entry(for symbol: String) -> EmojiEntry? {
        symbolIndex[symbol].map { entries[$0] }
    }

    func search(_ query: String, limit: Int = 120) -> [EmojiEntry] {
        let words = Self.normalize(query).split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return [] }
        return entries.indices.lazy.filter { index in words.allSatisfy { searchIndex[index].contains($0) } }
            .prefix(limit).map { entries[$0] }
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pl_PL"))
            .replacingOccurrences(of: "\u{0142}", with: "l")
    }
}
