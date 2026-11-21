@testable import Dictum
import Foundation
import Testing

struct QuickEmojiChoicesTests {
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
