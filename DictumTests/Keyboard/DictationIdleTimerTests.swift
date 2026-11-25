@testable import Dictum
import Foundation
import Testing

struct DictationIdleTimerTests {
    private let now = Date(timeIntervalSince1970: 1000)

    @Test func `an unused ready session expires after fifteen minutes`() {
        var timer = DictationIdleTimer()
        let expiry = [
            timer.hasExpired(phase: .ready, at: now),
            timer.hasExpired(phase: .ready, at: now.addingTimeInterval(899)),
            timer.hasExpired(phase: .ready, at: now.addingTimeInterval(900))
        ]
        #expect(expiry == [false, false, true])
    }

    @Test(arguments: [1, 5, 10, 15, 30, 60])
    func `standby uses the selected number of minutes`(minutes: Int) {
        var timer = DictationIdleTimer()
        let deadline = now.addingTimeInterval(TimeInterval(minutes) * 60)
        let initiallyExpired = timer.hasExpired(phase: .ready, at: now, minutes: minutes)
        #expect(!initiallyExpired)
        let expiredBeforeDeadline = timer.hasExpired(phase: .ready, at: deadline.addingTimeInterval(-1), minutes: minutes)
        #expect(!expiredBeforeDeadline)
        let expiredAtDeadline = timer.hasExpired(phase: .ready, at: deadline, minutes: minutes)
        #expect(expiredAtDeadline)
    }

    @Test func `interrupted standby keeps the original deadline`() throws {
        var timer = DictationIdleTimer()
        let initiallyExpired = timer.hasExpired(phase: .ready, at: now)
        #expect(!initiallyExpired)
        var standby = try #require(timer.interrupted(phase: .ready, at: now.addingTimeInterval(600)))
        let expiredBeforeDeadline = standby.hasExpired(phase: .ready, at: now.addingTimeInterval(899))
        #expect(!expiredBeforeDeadline)
        let expiredAtDeadline = standby.hasExpired(phase: .ready, at: now.addingTimeInterval(900))
        #expect(expiredAtDeadline)
    }

    @Test func `interruption before the first ready tick still has a deadline`() throws {
        var standby = try #require(DictationIdleTimer().interrupted(phase: .ready, at: now))
        let expiredAfterInterruption = standby.hasExpired(phase: .ready, at: now.addingTimeInterval(900))
        #expect(expiredAfterInterruption)
    }

    @Test(arguments: [KeyboardSession.Phase.recording, .transcribing, .result, .inactive])
    func `only standby can resume after an interruption`(phase: KeyboardSession.Phase) {
        #expect(DictationIdleTimer().interrupted(phase: phase, at: now) == nil)
    }

    @Test func `unlimited standby stays ready`() {
        var timer = DictationIdleTimer()
        let initiallyExpired = timer.hasExpired(phase: .ready, at: now, minutes: 0)
        #expect(!initiallyExpired)
        let expiredAfterDay = timer.hasExpired(phase: .ready, at: now.addingTimeInterval(86400), minutes: 0)
        #expect(!expiredAfterDay)
    }

    @Test(arguments: [KeyboardSession.Phase.recording, .transcribing, .result, .inactive])
    func `busy work and pending insertion get a fresh idle period`(phase: KeyboardSession.Phase) {
        var timer = DictationIdleTimer()
        let expiry = [
            timer.hasExpired(phase: .ready, at: now),
            timer.hasExpired(phase: phase, at: now.addingTimeInterval(400)),
            timer.hasExpired(phase: .ready, at: now.addingTimeInterval(401)),
            timer.hasExpired(phase: .ready, at: now.addingTimeInterval(1300)),
            timer.hasExpired(phase: .ready, at: now.addingTimeInterval(1301))
        ]
        #expect(expiry == [false, false, false, false, true])
    }
}
