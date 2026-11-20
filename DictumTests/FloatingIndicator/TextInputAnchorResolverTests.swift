import AppKit
@testable import Dictum
import Testing

struct TextInputAnchorResolverTests {
    private let builtIn = TextInputAnchorResolver.ScreenGeometry(
        frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
        visibleFrame: CGRect(x: 0, y: 0, width: 1710, height: 1073)
    )
    private let externalAbove = TextInputAnchorResolver.ScreenGeometry(
        frame: CGRect(x: -3440, y: 1107, width: 3440, height: 1440),
        visibleFrame: CGRect(x: -3440, y: 1107, width: 3440, height: 1440)
    )
    private let panelSize = NSSize(width: 210, height: 44)

    @Test
    func `pill sits beside a text area on a display above the primary one`() throws {
        let anchor = TextInputAnchorResolver.Anchor(
            rect: CGRect(x: -1373, y: -191, width: 710, height: 122),
            role: "AXTextArea",
            kind: .focusedElement
        )

        let origin = try #require(
            TextInputAnchorResolver.panelOrigin(for: anchor, panelSize: panelSize, screens: [builtIn, externalAbove])
        )

        #expect(origin == NSPoint(x: -1373 - 210 - 8, y: 1107 + 191 - 61 - 22))
    }

    @Test
    func `pill sits beside a caret on the primary display`() throws {
        let anchor = TextInputAnchorResolver.Anchor(
            rect: CGRect(x: 600, y: 500, width: 2, height: 20),
            role: "AXTextArea",
            kind: .caret
        )

        let origin = try #require(
            TextInputAnchorResolver.panelOrigin(for: anchor, panelSize: panelSize, screens: [builtIn, externalAbove])
        )

        #expect(origin == NSPoint(x: 600 - 210 - 8, y: 1107 - 500 - 20 - 12))
    }
}
