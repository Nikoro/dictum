@testable import Dictum
import Testing

struct KeyboardTrackpadTests {
    @Test func `small movements accumulate and reversing direction is symmetric`() {
        var trackpad = KeyboardTrackpad()
        let movement0 = trackpad.move(by: 3)
        #expect(movement0 == 0)
        let movement1 = trackpad.move(by: 5)
        #expect(movement1 == 1)
        let movement2 = trackpad.move(by: -24)
        #expect(movement2 == -3)
        let movement3 = trackpad.move(by: 24)
        #expect(movement3 == 3)
    }

    @Test func `new gesture discards the previous fractional movement`() {
        var trackpad = KeyboardTrackpad()
        let movement4 = trackpad.move(by: 7)
        #expect(movement4 == 0)
        trackpad = KeyboardTrackpad()
        let movement5 = trackpad.move(by: 1)
        #expect(movement5 == 0)
    }
}
