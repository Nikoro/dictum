import Foundation

enum KeyboardDeletionUnit {
    case character, word
}

enum KeyboardWordDeletion {
    static func count(in context: String?, hasSelection: Bool = false) -> Int {
        guard !hasSelection, let context, !context.isEmpty else { return 1 }
        var end = context.endIndex
        while end > context.startIndex {
            let previous = context.index(before: end)
            if context[previous].isNewline {
                break
            }
            guard context[previous].isWhitespace else { break }
            end = previous
        }
        let spaces = context.distance(from: end, to: context.endIndex)
        guard end > context.startIndex else { return min(64, max(1, spaces)) }
        return min(64, spaces + wordLength(in: context[..<end]))
    }

    private static func wordLength(in context: Substring) -> Int {
        var word: Range<Substring.Index>?
        context.enumerateSubstrings(
            in: context.startIndex ..< context.endIndex,
            options: [.byWords, .reverse, .substringNotRequired]
        ) { _, range, _, stop in
            word = range
            stop = true
        }
        guard let word, word.upperBound == context.endIndex else { return 1 }
        return context.distance(from: word.lowerBound, to: context.endIndex)
    }
}
