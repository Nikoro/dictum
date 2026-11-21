@testable import Dictum
import Foundation
import Testing

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

    @Test func `choosing a skin variant sets the preference and its base resets it`() throws {
        let suite = "Dictum.EmojiVariantTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = EmojiPreferences(defaults: defaults)
        preferences.record("👋🏽")
        #expect(preferences.tone == 3)
        preferences.record("👋")
        #expect(preferences.tone == 0)
    }

    @Test func `frequent ranking persists counts and resolves ties by most recent choice`() throws {
        let suite = "Dictum.EmojiFrequencyTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = EmojiPreferences(defaults: defaults)
        for symbol in ["😂", "😂", "😂", "❤️", "❤️", "👍"] {
            preferences.record(symbol)
        }
        #expect(EmojiPreferences(defaults: defaults).frequent(limit: 2) == ["😂", "❤️"])
        preferences.record("❤️")
        #expect(preferences.frequent(limit: 3) == ["❤️", "😂", "👍"])
    }

    @Test func `older recent history migrates without losing skin variants`() throws {
        let suite = "Dictum.EmojiMigrationTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["👋🏽", "👩‍💻"], forKey: "emoji.recents")
        #expect(EmojiPreferences(defaults: defaults).frequent(limit: 10) == ["👋🏽", "👩‍💻"])
    }
}
