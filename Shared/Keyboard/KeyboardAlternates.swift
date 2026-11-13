import Foundation

enum KeyboardAlternates {
    static func choices(for character: String, uppercase: Bool) -> [String] {
        ([character] + variants(for: character).map(String.init)).map {
            guard uppercase else { return $0 }
            return $0 == "ß" ? "ẞ" : $0.uppercased()
        }
    }

    private static func variants(for character: String) -> String {
        switch character {
        case "a": "ąàáâäæãåāă"
        case "c": "ćçč"
        case "d": "ďđ"
        case "e": "ęèéêëēėě"
        case "g": "ğģ"
        case "i": "ìíîïīįı"
        case "k": "ķ"
        case "l": "łľļ"
        case "n": "ńñňņ"
        case "o": "óôöòõœøō"
        case "r": "řŕ"
        case "s": "śšşß"
        case "t": "ťțţ"
        case "u": "ùúûüūůű"
        case "y": "ýÿ"
        case "z": "źżž"
        case "0": "°"
        case "-": "–—•"
        case ".": "…"
        case "!": "¡"
        case "?": "¿"
        case "'": "’‘ʼ"
        case "\"": "“”„«»"
        case "$": "€£¥₩₽¢"
        case "&": "§"
        default: ""
        }
    }
}

struct KeyboardAccentSelection: Sendable {
    let owner: UUID
    let symbols: [String]
    let frame: CGRect
    let keyboardOrigin: CGPoint
    let emoji: Bool
    var tablet = false
    var rowCount: Int {
        tablet && !emoji ? 2 : 1
    }

    var columns: Int {
        tablet && !emoji && symbols.count == 8 ? 5 : (symbols.count + rowCount - 1) / rowCount
    }

    private(set) var selectedIndex: Int

    init(owner: UUID, choices: [String], keyFrame: CGRect, keyboardFrame: CGRect, emoji: Bool = false, tablet: Bool = false) {
        precondition(!choices.isEmpty)
        self.owner = owner
        self.emoji = emoji
        self.tablet = tablet
        keyboardOrigin = keyboardFrame.origin
        if tablet, !emoji {
            symbols = Self.tabletSymbols(choices)
            let count = symbols.count > 5 ? (symbols.count == 8 ? 5 : (symbols.count + 1) / 2) : symbols.count
            let width = min(CGFloat(count) * 31 + 18, keyboardFrame.width - 12)
            frame = CGRect(
                x: min(max(keyFrame.midX - width / 2, keyboardFrame.minX + 6), keyboardFrame.maxX - width - 6),
                y: keyFrame.minY - 158,
                width: width,
                height: 154
            )
            selectedIndex = min(symbols.count - 1, symbols.count - count + count / 2)
            return
        }
        let width = min(ceil(CGFloat(choices.count) * (min(keyFrame.width, 34) + 4) + 20), keyboardFrame.width - 12)
        let cell = (width - 20) / CGFloat(choices.count)
        let nearest = min(max(Int((keyFrame.midX - keyboardFrame.minX - 16) / cell), 0), choices.count - 1)
        let aligned = keyFrame.midX - 10 - (CGFloat(nearest) + 0.5) * cell
        let origin = min(max(aligned, keyboardFrame.minX + 6), keyboardFrame.maxX - width - 6)
        frame = CGRect(x: origin, y: keyFrame.minY - 73, width: width, height: 68)
        let base = min(max(Int((keyFrame.midX - origin - 10) / cell), 0), choices.count - 1)
        selectedIndex = base
        symbols = Self.arranged(choices, base: base)
    }

    private static func tabletSymbols(_ choices: [String]) -> [String] {
        let ordered = choices.first?.lowercased() == "o" ? ["ō", "ø", "œ", "õ", "ö", "ó", "ô", "ò"]
            : Array(choices.dropFirst())
        if ordered.isEmpty {
            return choices
        }
        return choices.first == choices.first?.uppercased() ? ordered.map { $0.uppercased() } : ordered
    }

    private static func arranged(_ choices: [String], base: Int) -> [String] {
        var arranged = Array(repeating: "", count: choices.count)
        arranged[base] = choices[0]
        let positions = arranged.indices.filter { $0 != base }.sorted {
            abs($0 - base) == abs($1 - base) ? $0 > $1 : abs($0 - base) < abs($1 - base)
        }
        for (index, symbol) in zip(positions, choices.dropFirst()) {
            arranged[index] = symbol
        }
        return arranged
    }

    var selected: String {
        symbols[selectedIndex]
    }

    var topInset: CGFloat {
        max(0, keyboardOrigin.y - frame.minY + 8)
    }

    mutating func move(to location: CGPoint) {
        guard location.x.isFinite else { return }
        if rowCount > 1 {
            let upper = symbols.count - columns
            let row = location.y < frame.midY ? 0 : 1
            let count = row == 0 ? upper : columns
            let cell = (frame.width - 20) / CGFloat(columns)
            let inset = row == 0 ? CGFloat(columns - upper) * cell / 2 : 0
            let index = Int(max(0, location.x - frame.minX - 10 - inset) / cell)
            selectedIndex = (row == 0 ? 0 : upper) + min(max(0, index), count - 1)
            return
        }
        let cell = (frame.width - 20) / CGFloat(symbols.count)
        let position = min(max(location.x - frame.minX - 10, 0), frame.width - 20)
        selectedIndex = min(Int(position / cell), symbols.count - 1)
    }
}
