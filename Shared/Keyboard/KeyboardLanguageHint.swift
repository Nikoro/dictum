import Foundation

enum KeyboardLanguageHint {
    static func code(from identifier: String?) -> String? {
        guard let identifier, identifier.count <= 64,
              let primary = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: { $0 == "-" || $0 == "_" }).first?.lowercased(),
              (2 ... 3).contains(primary.count),
              primary != "und",
              primary.utf8.allSatisfy({ (97 ... 122).contains($0) }) else { return nil }
        return primary
    }
}
