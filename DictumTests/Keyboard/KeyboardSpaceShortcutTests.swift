@testable import Dictum
import Foundation
import Testing

struct KeyboardSpaceShortcutTests {
    private let now = Date(timeIntervalSince1970: 1000)

    @Test func `two fast spaces after a word replace the first with punctuation`() {
        var shortcut = KeyboardSpaceShortcut()
        let first = shortcut.replacesSpace(inserting: " ", before: "Hello", hasSelection: false, enabled: true, at: now)
        let second = shortcut.replacesSpace(
            inserting: " ", before: "Hello ", hasSelection: false, enabled: true, at: now.addingTimeInterval(0.2)
        )
        #expect(first == false)
        #expect(second)
    }

    @Test(arguments: ["", " ", "Hi! ", "Hi. ", "Hi\n ", "Hi  "])
    func `punctuation and whitespace do not gain another period`(_ context: String) {
        var shortcut = armedShortcut()
        let result = shortcut.replacesSpace(
            inserting: " ", before: context, hasSelection: false, enabled: true, at: now.addingTimeInterval(0.1)
        )
        #expect(result == false)
    }

    @Test(arguments: [0, 1, 2, 3])
    func `cursor movement slow taps selections and disabled fields preserve spaces`(_ scenario: Int) {
        var shortcut = armedShortcut()
        if scenario == 0 {
            shortcut.reset()
        }
        let result = shortcut.replacesSpace(
            inserting: " ",
            before: "word ",
            hasSelection: scenario == 2,
            enabled: scenario != 3,
            at: now.addingTimeInterval(scenario == 1 ? 0.5 : 0.1)
        )
        #expect(result == false)
    }

    @Test func `intervening characters and missing host context disable replacement`() {
        var shortcut = armedShortcut()
        _ = shortcut.replacesSpace(inserting: "x", before: "word ", hasSelection: false, enabled: true, at: now)
        let interrupted = shortcut.replacesSpace(inserting: " ", before: "word ", hasSelection: false, enabled: true, at: now)
        let missingContext = shortcut.replacesSpace(inserting: " ", before: nil, hasSelection: false, enabled: true, at: now)
        #expect(interrupted == false)
        #expect(missingContext == false)
    }

    private func armedShortcut() -> KeyboardSpaceShortcut {
        var shortcut = KeyboardSpaceShortcut()
        _ = shortcut.replacesSpace(inserting: " ", before: "word", hasSelection: false, enabled: true, at: now)
        return shortcut
    }
}
