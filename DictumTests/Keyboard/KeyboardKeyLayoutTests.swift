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

    @Test func `slightly low letter touches never open emoji`() throws {
        let layout = KeyboardKeyLayout(width: 402, tablet: false)
        let letter = try #require(layout.slots.first { $0.role == .character("z") })
        let emoji = try #require(layout.slots.first { $0.role == .emoji })
        #expect(layout.nearest(to: CGPoint(x: letter.frame.midX, y: emoji.frame.minY + 6))?.role == .character("z"))
        #expect(layout.nearest(to: CGPoint(x: emoji.frame.midX, y: emoji.frame.midY + 4))?.role == .emoji)
    }

    @Test func `typing bursts shrink the bottom modifier keys towards their lower half`() throws {
        let layout = KeyboardKeyLayout(width: 402, tablet: false)
        let emoji = try #require(layout.slots.first { $0.role == .emoji })
        let upper = CGPoint(x: emoji.frame.midX, y: emoji.frame.minY + 18)
        #expect(layout.nearest(to: upper)?.role == .emoji)
        #expect(layout.nearest(to: upper, typing: true)?.role == .character("z"))
        let lower = CGPoint(x: emoji.frame.midX, y: emoji.frame.maxY - 8)
        #expect(layout.nearest(to: lower, typing: true)?.role == .emoji)
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
