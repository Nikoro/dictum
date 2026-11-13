@testable import Dictum
import Foundation
import Testing

struct KeyboardSessionTests {
    private let now = Date(timeIntervalSince1970: 1000)

    @Test func `commands from an expired or different session cannot start recording`() {
        let session = KeyboardSession(id: UUID(), updatedAt: now, phase: .ready)
        var command = KeyboardCommand(sessionID: session.id, action: .start, createdAt: now)
        #expect(session.accepts(command, at: now))
        #expect(!session.accepts(command, at: now.addingTimeInterval(5)))
        command.sessionID = UUID()
        #expect(!session.accepts(command, at: now))
    }

    @Test func `a delayed stop cannot end the next recording`() {
        let session = KeyboardSession(id: UUID(), updatedAt: now, phase: .recording, recordingID: UUID())
        var command = KeyboardCommand(sessionID: session.id, recordingID: UUID(), action: .stop, createdAt: now)
        #expect(!session.accepts(command, at: now))
        command.recordingID = session.recordingID
        #expect(session.accepts(command, at: now))
        command.createdAt = now.addingTimeInterval(-10)
        #expect(!session.accepts(command, at: now))
    }

    @Test func `only the matching result can be consumed`() {
        let session = KeyboardSession(
            id: UUID(),
            updatedAt: now,
            phase: .result,
            recordingID: UUID(),
            transcript: "Example transcript"
        )
        var command = KeyboardCommand(sessionID: session.id, recordingID: UUID(), action: .consume, createdAt: now)
        #expect(!session.accepts(command, at: now))
        command.recordingID = session.recordingID
        #expect(session.accepts(command, at: now))
        command.action = .start
        #expect(!session.accepts(command, at: now))
    }

    @Test func `inactive and future heartbeats never report a live microphone`() {
        var session = KeyboardSession(id: UUID(), updatedAt: now, phase: .inactive)
        #expect(!session.isAvailable(at: now))
        session.phase = .ready
        #expect(!session.isAvailable(at: now.addingTimeInterval(-1)))
    }

    @Test(arguments: ["", " \n\t "])
    func `an empty recognition result returns to readiness without an error`(text: String) {
        var session = KeyboardSession(id: UUID(), updatedAt: now, phase: .transcribing, recordingID: UUID())
        session.completeTranscription(text)
        #expect(session.issue == nil)
        #expect(session.phase == .ready)
        #expect(session.transcript == nil)
        #expect(session.recordingID == nil)
    }

    @Test func `a later successful recognition clears the previous failure and keeps the result`() {
        var session = KeyboardSession(
            issue: .noSpeech,
            id: UUID(),
            updatedAt: now,
            phase: .transcribing,
            recordingID: UUID()
        )
        session.completeTranscription("  Example transcript ")
        #expect(session.issue == nil)
        #expect(session.phase == .result)
        #expect(session.transcript == "Example transcript")
    }

    @Test func `an expired result is cleared with an explanation`() {
        var session = KeyboardSession(
            id: UUID(),
            updatedAt: now,
            phase: .result,
            recordingID: UUID(),
            transcript: "Example transcript"
        )
        session.clearResult(issue: .resultExpired)
        #expect(session.phase == .ready)
        #expect(session.transcript == nil)
        #expect(session.issue == .resultExpired)
    }
}
