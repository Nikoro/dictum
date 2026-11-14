import UIKit

@MainActor
final class KeyboardTrackpadGesture: NSObject, UIGestureRecognizerDelegate {
    weak var plane: KeyboardPlaneView?
    private var movement = KeyboardTrackpad()
    private var previousX: CGFloat = 0
    private(set) var active = false
    private lazy var recognizer = UILongPressGestureRecognizer(target: self, action: #selector(update))

    func attach(to plane: KeyboardPlaneView) {
        self.plane = plane
        recognizer.minimumPressDuration = 0.35
        recognizer.allowableMovement = 12
        recognizer.delegate = self
        recognizer.delaysTouchesEnded = false
        plane.addGestureRecognizer(recognizer)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let plane, plane.model?.emojiSearchActive != true else { return false }
        return plane.layout.nearest(to: touch.location(in: plane))?.role == .space
    }

    @objc private func update() {
        guard let plane else { return }
        let position = recognizer.location(in: plane).x
        switch recognizer.state {
        case .began:
            active = true
            movement = KeyboardTrackpad()
            previousX = position
            plane.cancelTouches()
            plane.updateTrackpadAppearance()
            UISelectionFeedbackGenerator().selectionChanged()
        case .changed:
            let offset = movement.move(by: position - previousX)
            previousX = position
            if offset != 0 {
                plane.model?.moveCursor(offset)
            }
        case .ended, .cancelled, .failed:
            active = false
            plane.updateTrackpadAppearance()
        default: break
        }
    }

    func cancel() {
        recognizer.isEnabled = false
        recognizer.isEnabled = true
        active = false
        plane?.updateTrackpadAppearance()
    }
}
