import Foundation

struct KeyboardTrackpad {
    private var remainder: CGFloat = 0

    mutating func move(by distance: CGFloat) -> Int {
        remainder += distance
        let offset = Int(remainder / 8)
        remainder -= CGFloat(offset) * 8
        return offset
    }
}
