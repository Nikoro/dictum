@testable import Dictum
import Testing

struct KeyboardWordDeletionTests {
    @Test(arguments: [
        ("alpha bravo", 5),
        ("alpha bravo  ", 7),
        ("Zażółć gęślą", 5),
        ("hello world!", 1),
        ("hello\n", 1),
        ("hello 👨‍👩‍👧‍👦", 1),
        ("hello e\u{301}", 1),
        ("   ", 3),
        ("", 1)
    ])
    func `word deletion respects spaces punctuation newlines and composed characters`(text: String, count: Int) {
        #expect(KeyboardWordDeletion.count(in: text) == count)
    }

    @Test func `missing context falls back to one delete and long words bound work per tick`() {
        #expect(KeyboardWordDeletion.count(in: "alpha bravo", hasSelection: true) == 1)
        #expect(KeyboardWordDeletion.count(in: nil) == 1)
        #expect(KeyboardWordDeletion.count(in: String(repeating: "a", count: 1000)) == 64)
    }
}
