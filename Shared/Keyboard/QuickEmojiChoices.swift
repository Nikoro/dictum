import Foundation

enum QuickEmojiChoices {
    static let starters = [
        "😂", "❤️", "😍", "😒", "👌", "☺️", "😊", "😘", "😭", "😩",
        "💕", "😔", "😏", "😁", "😳", "👍", "✌️", "😉", "😌", "💁",
        "🙈", "😎", "🎶", "👀", "😑", "😴", "😄", "😜", "😋", "👏"
    ]

    static func capacity(width: CGFloat) -> Int {
        min(max(Int((width - 20) / 38), 1), 10)
    }

    static func filling(_ personal: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        return Array((personal + starters).filter { seen.insert($0).inserted }.prefix(max(limit, 0)))
    }
}
