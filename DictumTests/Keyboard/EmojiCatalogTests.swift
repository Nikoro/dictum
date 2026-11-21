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
