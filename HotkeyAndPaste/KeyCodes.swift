import Carbon.HIToolbox
import CoreGraphics

enum KeyCode {
    static let letterC = CGKeyCode(kVK_ANSI_C)
    static let letterV = CGKeyCode(kVK_ANSI_V)
    static let command = CGKeyCode(kVK_Command)
    static let rightCommand = CGKeyCode(kVK_RightCommand)
    static let escape = CGKeyCode(kVK_Escape)
}

enum ModifierKey {
    private static let keyCodes: Set<Int> = [
        kVK_Command, kVK_RightCommand, kVK_Shift, kVK_RightShift, kVK_CapsLock,
        kVK_Option, kVK_RightOption, kVK_Control, kVK_RightControl
    ]

    static func isModifier(_ keyCode: Int) -> Bool {
        keyCodes.contains(keyCode)
    }

    static func flag(forKeyCode keyCode: Int) -> CGEventFlags {
        switch keyCode {
        case kVK_Command, kVK_RightCommand: .maskCommand
        case kVK_Shift, kVK_RightShift: .maskShift
        case kVK_Option, kVK_RightOption: .maskAlternate
        case kVK_Control, kVK_RightControl: .maskControl
        default: []
        }
    }

    static func name(forKeyCode keyCode: Int) -> String? {
        let right = String(localized: "hotkey.right", defaultValue: "Right")
        let left = String(localized: "hotkey.left", defaultValue: "Left")
        switch keyCode {
        case kVK_RightCommand: return "\(right) ⌘"
        case kVK_Command: return "\(left) ⌘"
        case kVK_Shift: return "\(left) ⇧"
        case kVK_RightShift: return "\(right) ⇧"
        case kVK_Option: return "\(left) ⌥"
        case kVK_RightOption: return "\(right) ⌥"
        case kVK_Control: return "\(left) ⌃"
        case kVK_RightControl: return "\(right) ⌃"
        default: return nil
        }
    }
}

enum ANSIKeyNames {
    private static let mapping: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        50: "`",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 103: "F11", 105: "F13", 107: "F14",
        109: "F10", 111: "F12", 113: "F15",
        118: "F4", 119: "F2", 120: "F1",
        121: "Page Down", 122: "F16", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    static func keyName(for keyCode: Int) -> String? {
        mapping[keyCode]
    }
}
