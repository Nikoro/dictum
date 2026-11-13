@testable import Dictum
import Foundation
import Testing

struct DictationIdleTimerTests {
    private let now = Date(timeIntervalSince1970: 1000)

    @Test func `an unused ready session expires after five minutes`() {
        var timer = DictationIdleTimer()
        let expiry = [
            timer.hasExpired(phase: .ready, at: now),
            timer.hasExpired(phase: .ready, at: now.addingTimeInterval(299)),
            timer.hasExpired(phase: .ready, at: now.addingTimeInterval(300))
        ]
        #expect(expiry == [false, false, true])
    }

    @Test(arguments: [KeyboardSession.Phase.recording, .transcribing, .result, .inactive])
    func `busy work and pending insertion get a fresh idle period`(phase: KeyboardSession.Phase) {
        var timer = DictationIdleTimer()
        let expiry = [
            timer.hasExpired(phase: .ready, at: now),
            timer.hasExpired(phase: phase, at: now.addingTimeInterval(400)),
            timer.hasExpired(phase: .ready, at: now.addingTimeInterval(401)),
            timer.hasExpired(phase: .ready, at: now.addingTimeInterval(700)),
            timer.hasExpired(phase: .ready, at: now.addingTimeInterval(701))
        ]
        #expect(expiry == [false, false, false, false, true])
    }
}
