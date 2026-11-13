@testable import Dictum
import Testing

struct KeyboardInputModeKeysTests {
    @Test func `tablet retains emoji access when iPad requires the keyboard switcher`() {
        #expect(KeyboardInputModeKeys.required(tablet: true, needsSwitch: true) == [.emoji, .nextKeyboard])
    }

    @Test func `phone keeps its existing system switcher policy`() {
        #expect(KeyboardInputModeKeys.required(tablet: false, needsSwitch: true) == [.nextKeyboard])
        #expect(KeyboardInputModeKeys.required(tablet: false, needsSwitch: false) == [.emoji])
        #expect(KeyboardInputModeKeys.required(tablet: true, needsSwitch: false) == [.emoji])
    }
}
