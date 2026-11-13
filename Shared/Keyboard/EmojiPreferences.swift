import Foundation
import Observation

@Observable
@MainActor
final class EmojiPreferences {
    private(set) var recents: [String]
    private(set) var tone: Int
    private var frequencies: [String: Int]
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recents = Array((defaults.stringArray(forKey: "emoji.recents") ?? []).prefix(48))
        tone = min(max(defaults.integer(forKey: "emoji.skinTone"), 0), 5)
        frequencies = (defaults.dictionary(forKey: "emoji.frequencies") as? [String: Int] ?? [:]).filter { $0.value > 0 }
        for symbol in recents where frequencies[symbol] == nil {
            frequencies[symbol] = 1
        }
    }

    func record(_ symbol: String) {
        if let entry = EmojiCatalog.shared.entry(for: symbol), !entry.variants.isEmpty {
            selectTone(entry.variants.firstIndex(of: symbol).map { $0 + 1 } ?? 0)
        }
        recents.removeAll { $0 == symbol }
        recents.insert(symbol, at: 0)
        recents = Array(recents.prefix(48))
        frequencies[symbol] = min(frequencies[symbol] ?? 0, Int.max - 1) + 1
        let retained = Set(frequent(limit: 256))
        frequencies = frequencies.filter { retained.contains($0.key) }
        defaults.set(recents, forKey: "emoji.recents")
        defaults.set(frequencies, forKey: "emoji.frequencies")
    }

    func frequent(limit: Int) -> [String] {
        let recency = Dictionary(uniqueKeysWithValues: recents.enumerated().map { ($1, $0) })
        return Array(frequencies.keys.sorted {
            if frequencies[$0] != frequencies[$1] {
                return (frequencies[$0] ?? 0) > (frequencies[$1] ?? 0)
            }
            let first = recency[$0] ?? Int.max
            let second = recency[$1] ?? Int.max
            return first == second ? $0 < $1 : first < second
        }.prefix(max(limit, 0)))
    }

    func selectTone(_ tone: Int) {
        self.tone = min(max(tone, 0), 5)
        defaults.set(self.tone, forKey: "emoji.skinTone")
    }
}
