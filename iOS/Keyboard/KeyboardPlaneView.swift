import UIKit

final class KeyboardPlaneView: UIView {
    var layout = KeyboardKeyLayout(width: 402, tablet: false)
    var trackpadFill = UIColor.white
    weak var model: KeyboardModel?
    var activateRole: ((KeyboardKeyRole) -> Void)?
    private let trackpad = KeyboardTrackpadGesture()
    private var modifiers: [ObjectIdentifier: KeyboardModifierGesture] = [:]
    private var controls: [Int: UIControl] = [:]
    private var touches: [ObjectIdentifier: UIControl] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        trackpad.attach(to: self)
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
        guard !trackpad.active else { return }
        for touch in touches {
            guard let slot = layout.nearest(to: touch.location(in: self)),
                  let control = controls[slot.id], control.isEnabled else { continue }
            if [.shift, .numbers, .symbols].contains(slot.role), let model {
                guard modifiers.isEmpty else { continue }
                UIDevice.current.playInputClick()
                modifiers[ObjectIdentifier(touch)] = KeyboardModifierGesture(
                    role: slot.role, at: touch.location(in: self), model: model
                )
                continue
            }
            beginTracking(touch, control: control, event: event)
        }
    }

    private func beginTracking(_ touch: UITouch, control: UIControl, event: UIEvent?) {
        modifiers.values.forEach { $0.markUsed() }
        touches[ObjectIdentifier(touch)] = control
        if let key = control as? KeyboardAccentKeyControl {
            _ = key.beginTracking(touch, with: event)
        }
        if let key = control as? DeleteKeyButton {
            key.isHighlighted = true
            key.onPress?()
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
            if let modifier = modifiers.removeValue(forKey: ObjectIdentifier(touch)) {
                modifier.finish(at: touch.location(in: self), plane: self)
                continue
            }
            modifiers.values.forEach { $0.markUsed() }
            let control = self.touches.removeValue(forKey: ObjectIdentifier(touch))
            if let key = control as? KeyboardAccentKeyControl {
                key.endTracking(touch, with: event)
                if modifiers.values.contains(where: { $0.role == .shift }) {
                    model?.shift.hold()
                    model?.keysChanged()
                }
            }
            if let key = control as? DeleteKeyButton {
                key.isHighlighted = false; key.onRelease?()
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            modifiers.removeValue(forKey: ObjectIdentifier(touch))?.finish(at: nil, plane: self)
            let control = self.touches.removeValue(forKey: ObjectIdentifier(touch))
            if let key = control as? KeyboardAccentKeyControl {
                key.cancel()
            }
            if let key = control as? DeleteKeyButton {
                key.isHighlighted = false; key.onRelease?()
            }
        }
    }

    func cancelTouches() {
        let pending = modifiers.values
        modifiers.removeAll()
        pending.forEach { $0.finish(at: nil, plane: self) }
        for control in touches.values {
            (control as? KeyboardAccentKeyControl)?.cancel()
            if let key = control as? DeleteKeyButton {
                key.isHighlighted = false
                key.onRelease?()
            }
        }
        touches.removeAll()
    }

    func cancelGestures() {
        cancelTouches()
        trackpad.cancel()
    }

    func updateTrackpadAppearance() {
        for control in controls.values {
            if let key = control as? KeyboardAccentKeyControl {
                key.showTrackpad(trackpad.active, fill: trackpadFill)
            } else if let key = control as? DeleteKeyButton {
                key.imageView?.isHidden = trackpad.active
                key.backgroundColor = trackpad.active ? trackpadFill : key.normalFill
                key.alpha = trackpad.active ? 0.5 : 1
            }
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            cancelGestures()
        }
    }
}
