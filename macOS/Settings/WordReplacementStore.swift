import Foundation
import Observation

struct WordReplacement: Identifiable, Codable, Equatable {
    var id = UUID()
    var heard: String
    var replacement: String
}

@Observable
@MainActor
final class WordReplacementStore {
    static let shared = WordReplacementStore()

    var replacements: [WordReplacement] = [] {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKey.wordReplacements.rawValue),
           let saved = try? JSONDecoder().decode([WordReplacement].self, from: data)
        {
            replacements = saved
        }
    }

    func add() {
        replacements.append(WordReplacement(heard: "", replacement: ""))
    }

    func remove(_ id: WordReplacement.ID) {
        replacements.removeAll { $0.id == id }
    }

    func apply(to text: String) -> String {
        replacements.reduce(text) { result, rule in
            rule.heard.isEmpty ? result : Self.replacingWholeWords(rule.heard, with: rule.replacement, in: result)
        }
    }

    private static func replacingWholeWords(_ heard: String, with replacement: String, in text: String) -> String {
        let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: heard) + "(?![\\p{L}\\p{N}])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: NSRegularExpression.escapedTemplate(for: replacement)
        )
    }

    private func save() {
        if let data = try? JSONEncoder().encode(replacements) {
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.wordReplacements.rawValue)
        }
    }
}
