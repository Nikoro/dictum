@testable import Dictum
import Foundation
import Testing

struct KeyboardAlternatesTests {
    @Test func `vowels include Polish and other European variants in both cases`() {
        #expect(KeyboardAlternates.choices(for: "o", uppercase: false).contains("ö"))
        #expect(KeyboardAlternates.choices(for: "o", uppercase: false).contains("ó"))
        #expect(KeyboardAlternates.choices(for: "u", uppercase: true).contains("Ü"))
        #expect(KeyboardAlternates.choices(for: "a", uppercase: true).contains("Ą"))
        #expect(KeyboardAlternates.choices(for: "s", uppercase: true).contains("ẞ"))
        #expect(KeyboardAlternates.choices(for: "?", uppercase: false) == ["?", "¿"])
    }

    @Test(arguments: [CGFloat(20), 120, 220, 370])
    func `popup stays inside keyboard and releasing over the original key keeps the base`(position: CGFloat) {
        let keyboard = CGRect(x: 0, y: 500, width: 402, height: 221)
        let key = CGRect(x: position, y: 520, width: 28, height: 43)
        var selection = KeyboardAccentSelection(
            owner: UUID(),
            choices: KeyboardAlternates.choices(for: "o", uppercase: false),
            keyFrame: key,
            keyboardFrame: keyboard
        )
        #expect(selection.frame.minX >= 0)
        #expect(selection.frame.maxX <= keyboard.width)
        #expect(selection.selected == "o")
        selection.move(to: CGPoint(x: key.midX, y: 800))
        #expect(selection.selected == "o")
    }

    @Test func `sliding outside the popup keeps selecting and clamps at both ends`() {
        var selection = KeyboardAccentSelection(
            owner: UUID(),
            choices: ["o", "ó", "ö"],
            keyFrame: CGRect(x: 250, y: 500, width: 32, height: 43),
            keyboardFrame: CGRect(x: 0, y: 500, width: 402, height: 221)
        )
        selection.move(to: CGPoint(x: -100, y: 1000))
        #expect(selection.selected == selection.symbols.first)
        selection.move(to: CGPoint(x: 800, y: 200))
        #expect(selection.selected == selection.symbols.last)
    }
}
