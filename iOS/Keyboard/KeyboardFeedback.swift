import UIKit

@MainActor
enum KeyboardFeedback {
    private static let impact = UIImpactFeedbackGenerator(style: .light)

    static func keyDown() {
        UIDevice.current.playInputClick()
        impact.impactOccurred(intensity: 0.6)
        impact.prepare()
    }

    static func warmUp() {
        impact.prepare()
    }
}
