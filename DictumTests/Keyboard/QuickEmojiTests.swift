@testable import Dictum
import Foundation
import Testing

@MainActor
struct QuickEmojiTests {
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

    @Test func `quick strip fits the viewport without duplicates and personal choices lead`() {
        #expect(QuickEmojiChoices.capacity(width: 402) == 10)
        #expect(QuickEmojiChoices.capacity(width: 375) == 9)
        let choices = QuickEmojiChoices.filling(["👋🏽", "😂"], limit: 10)
        #expect(choices.count == 10)
        #expect(Set(choices).count == 10)
        #expect(Array(choices.prefix(2)) == ["👋🏽", "😂"])
        #expect(QuickEmojiChoices.filling([], limit: 0).isEmpty)
    }
}
