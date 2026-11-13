@testable import Dictum
import Foundation
import Testing

struct KeyboardMailboxTests {
    @Test func `commands are consumed once and corrupt commands do not block the queue`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let mailbox = try KeyboardMailbox(directory: root)
        let command = KeyboardCommand(sessionID: UUID(), action: .start)
        try mailbox.send(command)
        try Data("invalid".utf8).write(to: root.appendingPathComponent("broken.command"))
        let received = try mailbox.takeCommands()
        #expect(received.map(\.id) == [command.id])
        #expect(try mailbox.takeCommands().isEmpty)
    }

    @Test func `clearing a session removes its transcript and queued requests`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let mailbox = try KeyboardMailbox(directory: root)
        let session = KeyboardSession(
            id: UUID(),
            updatedAt: Date(),
            phase: .result,
            recordingID: UUID(),
            transcript: "Private example"
        )
        try mailbox.publish(session)
        #expect(try mailbox.readSession() == session)
        try mailbox.send(KeyboardCommand(sessionID: session.id, action: .start))
        try mailbox.clear()
        #expect(try mailbox.readSession() == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }
}
