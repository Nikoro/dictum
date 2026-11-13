import Foundation

struct KeyboardSession: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable {
        case inactive, ready, recording, transcribing, result
    }

    enum Issue: String, Codable, Sendable {
        case noAudio, noSpeech, resultExpired
    }

    var issue: Issue?
    var languageCode: String?
    var id: UUID
    var updatedAt: Date
    var phase: Phase
    var recordingID: UUID?
    var transcript: String?

    mutating func completeTranscription(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearResult()
            return
        }
        issue = nil
        transcript = trimmed
        phase = .result
    }

    mutating func clearResult(issue: Issue? = nil) {
        transcript = nil
        recordingID = nil
        phase = .ready
        self.issue = issue
    }

    func isAvailable(at date: Date) -> Bool {
        phase != .inactive && date.timeIntervalSince(updatedAt) >= 0 && date.timeIntervalSince(updatedAt) < 4
    }

    func accepts(_ command: KeyboardCommand, at date: Date) -> Bool {
        guard command.sessionID == id, isAvailable(at: date),
              date.timeIntervalSince(command.createdAt) >= 0,
              date.timeIntervalSince(command.createdAt) < 4
        else { return false }
        switch command.action {
        case .start: return phase == .ready
        case .stop, .cancel: return phase == .recording && command.recordingID == recordingID
        case .consume: return phase == .result && command.recordingID == recordingID
        }
    }
}

struct KeyboardCommand: Codable, Sendable {
    enum Action: String, Codable, Sendable {
        case start, stop, cancel, consume
    }

    var id = UUID()
    var sessionID: UUID
    var recordingID: UUID?
    var action: Action
    var createdAt = Date()
    var language: String?
}

extension KeyboardSession.Issue {
    var message: String? {
        switch self {
        case .noAudio, .noSpeech: nil
        case .resultExpired: String(localized: "ios.issue.expired")
        }
    }
}
