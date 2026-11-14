import Foundation

struct KeyboardShiftState {
    enum Mode { case lowercase, uppercase, locked }
    private(set) var mode = Mode.uppercase
    private var lastTap: Date?

    var isUppercase: Bool {
        mode != .lowercase
    }

    mutating func tap(at date: Date = .now) {
        if mode == .locked {
            mode = .lowercase
            lastTap = nil
        } else if let lastTap, (0 ... 0.35).contains(date.timeIntervalSince(lastTap)) {
            mode = .locked
            self.lastTap = nil
        } else {
            mode = mode == .uppercase ? .lowercase : .uppercase
            lastTap = date
        }
    }

    mutating func hold() {
        if mode != .locked {
            mode = .uppercase
        }
        lastTap = nil
    }

    mutating func didTypeLetter() {
        if mode == .uppercase {
            mode = .lowercase
        }
        lastTap = nil
    }

    mutating func toggleLock() {
        mode = mode == .locked ? .lowercase : .locked
        lastTap = nil
    }
}
