import Foundation

@MainActor struct KeyboardActionAppearance {
    var title = ""
    var symbol: String?
    var asset: String?
    var label = ""
    var purple = false
    var recording = false
    var selected = false
    var enabled = true
    var busy = false
    var modifier = true

    init(role: KeyboardKeyRole, model: KeyboardModel, tablet: Bool) {
        modifier = role != .space && role != .dictation
        switch role {
        case .tab: symbol = "arrow.right.to.line"; label = String(localized: "ios.keyboard.tab")
        case .capsLock: configureCapsLock(model)
        case .shift: configureShift(model, tablet: tablet)
        case .enter: symbol = "return"; label = String(localized: "ios.keyboard.return")
        case .numbers: configureNumbers(model, tablet: tablet)
        case .symbols: title = model.symbols ? "123" : "#+="; label = title
        case .emoji: asset = "KeyboardEmojiFace"; label = String(localized: "ios.keyboard.emoji")
        case .nextKeyboard: symbol = "globe"; label = String(localized: "ios.keyboard.next")
        case .space: label = String(localized: "ios.keyboard.space")
        case .dismiss: symbol = "keyboard.chevron.compact.down"; label = String(localized: "ios.keyboard.dismiss")
        case .dictation: configureDictation(model)
        case .undo: symbol = "arrow.uturn.backward"; label = String(localized: "ios.keyboard.undo"); enabled = model.canUndo
        case .redo: symbol = "arrow.uturn.forward"; label = String(localized: "ios.keyboard.redo"); enabled = model.canRedo
        case .character, .delete: break
        }
    }

    private mutating func configureCapsLock(_ model: KeyboardModel) {
        symbol = model.shift.mode == .locked ? "capslock.fill" : "capslock"
        label = String(localized: "ios.keyboard.caps_lock")
        selected = model.shift.mode == .locked
    }

    private mutating func configureShift(_ model: KeyboardModel, tablet: Bool) {
        symbol = model.shift.mode == .locked && !tablet ? "capslock.fill" : model.uppercase ? "shift.fill" : "shift"
        label = String(localized: "ios.keyboard.shift")
        selected = model.uppercase
    }

    private mutating func configureNumbers(_ model: KeyboardModel, tablet: Bool) {
        title = model.numbers ? "ABC" : tablet ? ".?123" : "123"
        label = title
    }

    private mutating func configureDictation(_ model: KeyboardModel) {
        recording = model.session?.phase == .recording
        busy = model.session?.phase == .transcribing || model.session?.phase == .result
        enabled = !busy && !model.pending
        purple = !recording
        asset = recording ? nil : "AppLogo"
        symbol = recording ? "stop.fill" : nil
        label = String(localized: recording ? "ios.stop" : model.session == nil ? "ios.keyboard.open" : "ios.record")
        if busy {
            asset = nil; symbol = nil; purple = false; label = String(localized: "ios.status.transcribing")
        }
    }
}
