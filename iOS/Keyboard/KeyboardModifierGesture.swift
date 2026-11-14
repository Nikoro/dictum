import UIKit

@MainActor
final class KeyboardModifierGesture {
    let role: KeyboardKeyRole
    private let shift: KeyboardShiftState
    private let numbers: Bool
    private let symbols: Bool
    private var used = false
    private let origin: CGPoint

    init(role: KeyboardKeyRole, at point: CGPoint, model: KeyboardModel) {
        self.role = role
        origin = point
        shift = model.shift
        numbers = model.numbers
        symbols = model.symbols
        switch role {
        case .shift: model.shift.hold()
        case .numbers: model.numbers.toggle(); model.symbols = false
        case .symbols: model.symbols.toggle()
        default: break
        }
        model.keysChanged()
    }

    func markUsed() {
        used = true
    }

    func finish(at point: CGPoint?, plane: KeyboardPlaneView) {
        guard let model = plane.model else { return }
        if let point, hypot(point.x - origin.x, point.y - origin.y) > 12,
           let slot = plane.layout.nearest(to: point), case .character = slot.role
        {
            used = true
            plane.activateRole?(slot.role)
        }
        if point == nil || used || role == .shift {
            model.shift = shift
            model.numbers = numbers
            model.symbols = symbols
        }
        if point != nil, !used, role == .shift {
            model.shift.tap()
        }
        model.keysChanged()
    }
}
