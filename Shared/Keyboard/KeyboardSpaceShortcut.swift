import Foundation

struct KeyboardSpaceShortcut {
    private var lastSpace: Date?

    mutating func reset() {
        lastSpace = nil
    }

    mutating func replacesSpace(
        inserting text: String,
        before: String?,
        hasSelection: Bool,
        enabled: Bool,
        at now: Date = .now
    ) -> Bool {
        defer { lastSpace = text == " " && enabled && !hasSelection ? now : nil }
        guard text == " ", enabled, !hasSelection, let lastSpace,
              (0 ... 0.3).contains(now.timeIntervalSince(lastSpace)),
              let before, before.last == " ", let previous = before.dropLast().last,
              previous.isLetter || previous.isNumber else { return false }
        return true
    }
}
