@testable import Dictum
import Foundation
import Testing

struct KeyboardLanguageHintTests {
    @Test func `regional keyboard identifiers resolve to model language codes`() {
        #expect(KeyboardLanguageHint.code(from: "pl-PL") == "pl")
        #expect(KeyboardLanguageHint.code(from: "EN_us") == "en")
        #expect(KeyboardLanguageHint.code(from: "ru-RU") == "ru")
        #expect(KeyboardLanguageHint.code(from: "pt-Latn-BR") == "pt")
        #expect(KeyboardLanguageHint.code(from: nil) == nil)
        #expect(KeyboardLanguageHint.code(from: "emoji") == nil)
        #expect(KeyboardLanguageHint.code(from: "123") == nil)
        #expect(KeyboardLanguageHint.code(from: "und") == nil)
    }

    @Test func `the bridge preserves the language and still reads older commands`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let mailbox = try KeyboardMailbox(directory: root)
        let command = KeyboardCommand(sessionID: UUID(), action: .start, language: "pl-PL")
        try mailbox.send(command)
        let received = try #require(mailbox.takeCommands().first)
        #expect(received.language == "pl-PL")
        var old = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(command)) as? [String: Any])
        old.removeValue(forKey: "language")
        let decoded = try JSONDecoder().decode(KeyboardCommand.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(decoded.language == nil)
        #expect(decoded.sessionID == command.sessionID)
    }
}
