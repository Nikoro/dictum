enum KeyboardInputModeKey: Equatable {
    case emoji
    case nextKeyboard
}

enum KeyboardInputModeKeys {
    static func required(tablet: Bool, needsSwitch: Bool) -> [KeyboardInputModeKey] {
        if tablet {
            return needsSwitch ? [.emoji, .nextKeyboard] : [.emoji]
        }
        return needsSwitch ? [.nextKeyboard] : [.emoji]
    }
}
