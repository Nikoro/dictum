import SwiftUI
import UIKit

struct KeyboardDeleteKey: UIViewRepresentable {
    let model: KeyboardModel
    let palette: KeyboardPalette
    var filled = true
    var foregroundOpacity = 1.0

    func makeUIView(context: Context) -> DeleteKeyButton {
        let button = DeleteKeyButton(type: .custom)
        button.setImage(UIImage(systemName: "delete.left"), for: .normal)
        button.setPreferredSymbolConfiguration(.init(pointSize: 20), forImageIn: .normal)
        button.layer.cornerRadius = 8
        button.accessibilityLabel = String(localized: "ios.keyboard.delete")
        return button
    }

    func updateUIView(_ button: DeleteKeyButton, context: Context) {
        button.onPress = model.startDeleting
        button.onRelease = model.stopDeleting
        button.tintColor = UIColor(palette.foreground.opacity(foregroundOpacity))
        button.normalFill = filled ? UIColor(palette.modifier) : .clear
        button.pressedFill = UIColor(palette.pressedKey)
        button.backgroundColor = button.isHighlighted ? button.pressedFill : button.normalFill
    }

    static func dismantleUIView(_ button: DeleteKeyButton, coordinator: ()) {
        button.onRelease?()
    }
}

final class DeleteKeyButton: UIButton {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var normalFill = UIColor.clear
    var pressedFill = UIColor.clear

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -12, dy: -12).contains(point)
    }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? pressedFill : normalFill }
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let accepted = super.beginTracking(touch, with: event)
        if accepted {
            onPress?()
        }
        return accepted
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard bounds.contains(touch.location(in: self)) else {
            onRelease?()
            return false
        }
        return super.continueTracking(touch, with: event)
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        onRelease?()
        super.endTracking(touch, with: event)
    }

    override func cancelTracking(with event: UIEvent?) {
        onRelease?()
        super.cancelTracking(with: event)
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        if newWindow == nil {
            onRelease?()
        }
        super.willMove(toWindow: newWindow)
    }

    override func accessibilityActivate() -> Bool {
        onPress?()
        onRelease?()
        return true
    }
}
