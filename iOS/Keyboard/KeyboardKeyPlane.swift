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
    }

    private func configure(_ button: DeleteKeyButton) {
        button.onPress = model.startDeleting
        button.onRelease = model.stopDeleting
        button.normalFill = UIColor(palette.modifier)
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
        case .space: type(" ")
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
        case .character, .delete: break
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

final class KeyboardPlaneView: UIView {
    var layout = KeyboardKeyLayout(width: 402, tablet: false)
    private var controls: [Int: UIControl] = [:]
    private var touches: [ObjectIdentifier: UIControl] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = UIColor.black.withAlphaComponent(0.01)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func control(for slot: KeyboardKeySlot) -> UIControl {
        if let control = controls[slot.id], (control is DeleteKeyButton) == (slot.role == .delete) {
            return control
        }
        controls[slot.id]?.removeFromSuperview()
        let control: UIControl
        if slot.role == .delete {
            let button = DeleteKeyButton(type: .custom)
            button.setImage(UIImage(systemName: "delete.left"), for: .normal)
            button.setPreferredSymbolConfiguration(.init(pointSize: layout.tablet ? 22 : 20), forImageIn: .normal)
            button.layer.cornerRadius = 8
            button.accessibilityLabel = String(localized: "ios.keyboard.delete")
            control = button
        } else {
            control = KeyboardAccentKeyControl()
        }
        controls[slot.id] = control
        addSubview(control)
        return control
    }

    func removeUnusedControls() {
        let retained = Set(layout.slots.map(\.id))
        for id in controls.keys where !retained.contains(id) {
            controls.removeValue(forKey: id)?.removeFromSuperview()
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        isUserInteractionEnabled && !isHidden && bounds.contains(point) ? self : nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let slot = layout.nearest(to: touch.location(in: self)),
                  let control = controls[slot.id], control.isEnabled else { continue }
            self.touches[ObjectIdentifier(touch)] = control
            if let key = control as? KeyboardAccentKeyControl {
                _ = key.beginTracking(touch, with: event)
            }
            if let key = control as? DeleteKeyButton {
                key.isHighlighted = true; key.onPress?()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let key = self.touches[ObjectIdentifier(touch)] as? KeyboardAccentKeyControl {
                _ = key.continueTracking(touch, with: event)
            } else if let key = self.touches[ObjectIdentifier(touch)] as? DeleteKeyButton,
                      !key.bounds.contains(touch.location(in: key))
            {
                key.onRelease?()
                key.isHighlighted = false
                self.touches.removeValue(forKey: ObjectIdentifier(touch))
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let control = self.touches.removeValue(forKey: ObjectIdentifier(touch))
            if let key = control as? KeyboardAccentKeyControl {
                key.endTracking(touch, with: event)
            }
            if let key = control as? DeleteKeyButton {
                key.isHighlighted = false; key.onRelease?()
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let control = self.touches.removeValue(forKey: ObjectIdentifier(touch))
            if let key = control as? KeyboardAccentKeyControl {
                key.cancel()
            }
            if let key = control as? DeleteKeyButton {
                key.isHighlighted = false; key.onRelease?()
            }
        }
    }
}
