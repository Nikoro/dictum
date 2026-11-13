import Foundation

struct KeyboardResultDelivery {
    enum Decision: Equatable {
        case waiting, discard, insert(String)
    }

    private var sessionID: UUID?
    private var documentID: UUID?
    private var recordingID: UUID?

    mutating func begin(sessionID: UUID, documentID: UUID) {
        self.sessionID = sessionID
        self.documentID = documentID
        recordingID = nil
    }

    mutating func observe(_ session: KeyboardSession?) {
        guard let session, session.id == sessionID else {
            cancel()
            return
        }
        if session.phase == .recording {
            recordingID = session.recordingID
        }
    }

    mutating func result(from session: KeyboardSession, in documentID: UUID, at date: Date) -> Decision {
        guard session.phase == .result else { return .waiting }
        defer { cancel() }
        guard session.id == sessionID, session.recordingID == recordingID, recordingID != nil,
              self.documentID == documentID, session.isAvailable(at: date),
              let text = session.transcript, !text.isEmpty
        else { return .discard }
        return .insert(text)
    }

    mutating func cancel() {
        sessionID = nil
        documentID = nil
        recordingID = nil
    }
}
