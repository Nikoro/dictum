@testable import Dictum
import Foundation
import Testing

struct KeyboardResultDeliveryTests {
    @Test func `stopping dictation delivers the result once without a confirmation action`() {
        var delivery = KeyboardResultDelivery()
        let document = UUID()
        var session = KeyboardSession(id: UUID(), updatedAt: Date(), phase: .recording, recordingID: UUID())
        delivery.begin(sessionID: session.id, documentID: document)
        delivery.observe(session)
        session.completeTranscription("Example transcript")
        #expect(delivery.result(from: session, in: document, at: Date()) == .insert("Example transcript"))
        #expect(delivery.result(from: session, in: document, at: Date()) == .discard)
    }

    @Test func `changing the focused field never inserts a result into the new field`() {
        var delivery = KeyboardResultDelivery()
        var session = KeyboardSession(id: UUID(), updatedAt: Date(), phase: .recording, recordingID: UUID())
        delivery.begin(sessionID: session.id, documentID: UUID())
        delivery.observe(session)
        session.completeTranscription("Example transcript")
        #expect(delivery.result(from: session, in: UUID(), at: Date()) == .discard)
    }

    @Test func `leaving the keyboard cancels automatic insertion`() {
        var delivery = KeyboardResultDelivery()
        let document = UUID()
        var session = KeyboardSession(id: UUID(), updatedAt: Date(), phase: .recording, recordingID: UUID())
        delivery.begin(sessionID: session.id, documentID: document)
        delivery.observe(session)
        delivery.cancel()
        session.completeTranscription("Example transcript")
        #expect(delivery.result(from: session, in: document, at: Date()) == .discard)
    }

    @Test func `a stale or unrelated recording cannot be inserted automatically`() {
        var delivery = KeyboardResultDelivery()
        let document = UUID()
        var session = KeyboardSession(id: UUID(), updatedAt: Date(), phase: .recording, recordingID: UUID())
        delivery.begin(sessionID: session.id, documentID: document)
        delivery.observe(session)
        session.recordingID = UUID()
        session.completeTranscription("Example transcript")
        #expect(delivery.result(from: session, in: document, at: Date()) == .discard)
    }
}
