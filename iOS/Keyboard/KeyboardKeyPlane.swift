import SwiftUI
import UIKit

struct KeyboardKeyPlane: UIViewRepresentable {
    let layout: KeyboardKeyLayout
    let model: KeyboardModel
    let palette: KeyboardPalette
    let insert: (String) -> Void
    let start: () -> Void
    let nextKeyboard: () -> Void
    let dismiss: () -> Void
    let openApp: () -> Void

    func makeUIView(context: Context) -> KeyboardPlaneView {
        KeyboardPlaneView()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: KeyboardPlaneView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? layout.width, height: layout.height)
    }

    func updateUIView(_ view: KeyboardPlaneView, context: Context) {
        render(view)
    }

    func render(_ view: KeyboardPlaneView) {
        view.trackpadFill = UIColor(palette.key)
        view.model = model
        view.activateRole = activate
        view.layout = layout
        for slot in layout.slots {
            let control = view.control(for: slot)
            control.frame = slot.frame
            if let delete = control as? DeleteKeyButton {
                configure(delete)
            } else if let key = control as? KeyboardAccentKeyControl {
                key.visualInsets = UIEdgeInsets(
                    top: layout.rowGap / 2,
                    left: layout.gap / 2,
                    bottom: layout.rowGap / 2,
                    right: layout.gap / 2
                )
                key.frame = slot.frame.insetBy(dx: -layout.gap / 2, dy: -layout.rowGap / 2)
                configure(key, role: slot.role, trailing: slot.frame.midX > layout.width / 2)
            }
        }
        view.removeUnusedControls()
        view.updateTrackpadAppearance()
    }

    private func configure(_ button: DeleteKeyButton) {
        button.onPress = model.startDeleting
        button.onRelease = model.stopDeleting
        button.normalFill = UIColor(layout.tablet ? palette.key : palette.modifier)
        button.pressedFill = UIColor(palette.pressedKey)
        button.backgroundColor = button.isHighlighted ? button.pressedFill : button.normalFill
        button.tintColor = UIColor(palette.foreground)
    }

    private func configure(_ control: KeyboardAccentKeyControl, role: KeyboardKeyRole, trailing: Bool) {
        control.tablet = layout.tablet
        if case let .character(text, hint) = role {
            control.configure(
                choices: KeyboardAlternates.choices(for: text, uppercase: model.uppercase),
                palette: palette,
                model: model
            ) { value in
                type(value)
                if !model.numbers {
                    model.shift.didTypeLetter()
                }
                model.keysChanged()
            }
            control.configureDecoration(hint: hint, tablet: layout.tablet)
        } else {
            configureAction(control, role: role, trailing: trailing)
        }
    }

    private func configureAction(_ control: KeyboardAccentKeyControl, role: KeyboardKeyRole, trailing: Bool) {
        let capacity = QuickEmojiChoices.capacity(width: layout.width)
        let choices = role == .emoji
            ? QuickEmojiChoices.filling(model.emojiPreferences.frequent(limit: capacity), limit: capacity) : [""]
        control.configure(choices: choices, palette: palette, model: model, tap: { activate(role) }, insert: { symbol in
            type(symbol)
            model.emojiPreferences.record(symbol)
        })
        let appearance = KeyboardActionAppearance(role: role, model: model, tablet: layout.tablet)
        control.configureAction(appearance, palette: palette)
        control.iconEdge = role == .enter || role == .shift && trailing ? 1 : -1
        control.loweredIcon = [.tab, .capsLock, .shift, .enter].contains(role)
    }

    private func activate(_ role: KeyboardKeyRole) {
        defer { model.keysChanged() }
        switch role {
        case .tab: type("\t")
        case .enter:
            if model.emojiSearchActive {
                model.emojiSearchActive = false
            } else {
                type("\n")
            }
        case .space:
            type(" ")
            model.numbers = false
            model.symbols = false
        case .shift: model.shift.tap()
        case .capsLock: model.shift.toggleLock()
        case .numbers: model.numbers.toggle()
        case .symbols: model.symbols.toggle()
        case .emoji: model.emojiSearchActive = false; model.emoji.toggle(); model.numbers = false
        case .nextKeyboard: nextKeyboard()
        case .dismiss: dismiss()
        case .undo: model.undoAction()
        case .redo: model.redoAction()
        case .dictation: activateDictation()
        case let .character(text, _):
            type(model.uppercase ? text.uppercased() : text)
            model.shift.didTypeLetter()
        case .delete: break
        }
    }

    private func activateDictation() {
        model.dismissNotice()
        guard let session = model.session, session.phase != .inactive else { openApp(); return }
        if session.phase == .ready {
            start()
        }
        if session.phase == .recording {
            model.send(.stop)
        }
    }

    private func type(_ text: String) {
        if model.emojiSearchActive {
            model.emojiQuery += text
        } else {
            insert(text)
        }
    }
}
