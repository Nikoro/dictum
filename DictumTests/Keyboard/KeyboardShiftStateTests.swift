@testable import Dictum
import Foundation
import Testing

struct KeyboardShiftStateTests {
    private let now = Date(timeIntervalSince1970: 1000)

    @Test func `double tapping shift locks capitals across multiple letters and a tap unlocks`() {
        var shift = KeyboardShiftState()
        shift.tap(at: now)
        shift.tap(at: now.addingTimeInterval(0.2))
        #expect(shift.mode == .locked)
        shift.didTypeLetter()
        shift.didTypeLetter()
        #expect(shift.isUppercase)
        shift.tap(at: now.addingTimeInterval(1))
        #expect(shift.mode == .lowercase)
    }

    @Test func `a single capital resets after typing and slow taps never lock`() {
        var shift = KeyboardShiftState()
        shift.didTypeLetter()
        #expect(!shift.isUppercase)
        shift.tap(at: now)
        #expect(shift.mode == .uppercase)
        shift.tap(at: now.addingTimeInterval(0.6))
        #expect(shift.mode == .lowercase)
        shift.tap(at: now.addingTimeInterval(1.2))
        shift.didTypeLetter()
        #expect(shift.mode == .lowercase)
    }
}
