@testable import Dictum
import Foundation
import Testing

struct KeyboardKeyLayoutTests {
    @Test func `phone key plane uses extra container height below its requested top inset`() {
        let layout = KeyboardKeyLayout(width: 402, tablet: false)
        #expect(layout.verticalOrigin(containerHeight: 223) == 7)
        #expect(layout.verticalOrigin(containerHeight: 216) == 0)
        #expect(layout.verticalOrigin(containerHeight: 253, topInset: 30) == 37)
        #expect(layout.verticalOrigin(containerHeight: 200) == 0)
        let tablet = KeyboardKeyLayout(width: 820, tablet: true)
        #expect(tablet.verticalOrigin(containerHeight: 337) == 0)
    }

    @Test func `rapid touches in key gaps retain their nearest character`() {
        let layout = KeyboardKeyLayout(width: 402, tablet: false)
        let first = layout.slots[0].frame
        #expect(layout.nearest(to: CGPoint(x: first.maxX + 1, y: first.midY))?.role == .character("q"))
        #expect(layout.nearest(to: CGPoint(x: first.midX, y: first.maxY + 1))?.role == .character("q"))
        #expect(layout.nearest(to: CGPoint(x: -50, y: -50)) == nil)
    }

    @Test(arguments: [CGFloat(744), 820, 834, 1024, 1180, 1366])
    func `tablet rows stay inside the keyboard with and without a required globe`(width: CGFloat) {
        for needsSwitch in [true, false] {
            let layout = KeyboardKeyLayout(width: width, tablet: true, landscape: width > 1024, needsSwitch: needsSwitch)
            for slot in layout.slots {
                #expect(slot.frame.minX >= 0)
                #expect(slot.frame.maxX <= width + 0.5)
                #expect(slot.frame.width > 20)
                #expect(slot.frame.maxY <= layout.height)
            }
        }
    }
}
