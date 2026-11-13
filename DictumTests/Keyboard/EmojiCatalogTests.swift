@testable import Dictum
import Foundation
import Testing

struct EmojiCatalogTests {
    @Test func `bundled catalog covers every category and resolves full emoji sequences`() throws {
        let catalog = EmojiCatalog.shared
        #expect(catalog.entries.count > 1800)
        #expect(Set(catalog.entries.map(\.category)) == Set(0 ... 7))
        #expect(Set(catalog.entries.map(\.symbol)).count == catalog.entries.count)
        #expect(catalog.entry(for: "👩‍💻")?.symbol == "👩‍💻")
        let hand = try #require(catalog.entry(for: "👋"))
        #expect(hand.symbol(tone: 3) == "👋🏽")
        #expect(catalog.entry(for: "👋🏽")?.symbol == "👋")
    }

    @Test func `search supports English and Polish without accents and bounds results`() {
        let catalog = EmojiCatalog.shared
        #expect(catalog.search("thumbs up").contains { $0.symbol == "👍" })
        #expect(catalog.search("zolw").contains { $0.symbol == "🐢" })
        #expect(catalog.search("FLAG", limit: 12).count == 12)
        #expect(catalog.search("  \n ").isEmpty)
        #expect(catalog.search("xyznomatchingemoji12345").isEmpty)
    }
}

@MainActor
struct EmojiPreferencesTests {
    @Test func `recents move to front without duplicates and survive a new keyboard instance`() throws {
        let suite = "Dictum.EmojiTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = EmojiPreferences(defaults: defaults)
        preferences.record("👩‍💻")
        preferences.record("👋🏽")
        preferences.record("👩‍💻")
        preferences.selectTone(3)
        let reloaded = EmojiPreferences(defaults: defaults)
        #expect(reloaded.recents == ["👩‍💻", "👋🏽"])
        #expect(reloaded.tone == 3)
    }

    @Test func `history stays bounded and invalid skin preferences are clamped`() throws {
        let suite = "Dictum.EmojiTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = EmojiPreferences(defaults: defaults)
        for entry in EmojiCatalog.shared.entries.prefix(80) {
            preferences.record(entry.symbol)
        }
        #expect(preferences.recents.count == 48)
        preferences.selectTone(99)
        #expect(preferences.tone == 5)
    }
}
