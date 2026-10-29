import AppKit

enum TextInputAnchorResolver {
    enum Kind: String {
        case caret
        case focusedElement
    }

    struct Anchor {
        let rect: CGRect
        let role: String
        let kind: Kind
    }

    static func resolve(preferredPID: pid_t) -> Anchor? {
        if let focusedElement = AXBridge.focusedElement(), let anchor = resolve(from: focusedElement) {
            return anchor
        }

        guard preferredPID > 0,
              let focusedElement = AXBridge.focusedElement(in: AXUIElementCreateApplication(preferredPID))
        else {
            return nil
        }

        return resolve(from: focusedElement)
    }

    static func panelOrigin(for anchor: Anchor, panelSize: NSSize) -> NSPoint? {
        guard let screen = screen(containingAXRect: anchor.rect) else {
            return nil
        }

        let anchorRect = convertAXRectToAppKit(anchor.rect)
        let spacing: CGFloat = 8
        let preferredLeftX = anchorRect.minX - panelSize.width - spacing
        let fallbackRightX = anchorRect.maxX + spacing
        var originX = preferredLeftX
        var originY = anchor.kind == .caret
            ? anchorRect.minY - (panelSize.height - anchorRect.height) / 2
            : anchorRect.midY - panelSize.height / 2

        if preferredLeftX < screen.visibleFrame.minX {
            originX = fallbackRightX
        }

        originX = max(originX, screen.visibleFrame.minX)
        originX = min(originX, screen.visibleFrame.maxX - panelSize.width)
        originY = max(originY, screen.visibleFrame.minY)
        originY = min(originY, screen.visibleFrame.maxY - panelSize.height)

        return NSPoint(x: originX, y: originY)
    }

    private static func resolve(from startingElement: AXUIElement) -> Anchor? {
        for element in ancestorChain(startingAt: startingElement, limit: 8) {
            let elementRole = role(of: element)
            if let caretRect = caretRect(for: element, role: elementRole) {
                return Anchor(rect: caretRect, role: elementRole, kind: .caret)
            }
            if isTextInputElement(element, role: elementRole), let elementRect = frame(of: element) {
                return Anchor(rect: elementRect, role: elementRole, kind: .focusedElement)
            }
        }

        return nil
    }

    private static func ancestorChain(startingAt element: AXUIElement, limit: Int) -> [AXUIElement] {
        var chain: [AXUIElement] = []
        var current: AXUIElement? = element

        while let node = current, chain.count < limit {
            chain.append(node)
            current = AXBridge.elementAttribute(kAXParentAttribute, of: node)
        }

        return chain
    }

    private static func role(of element: AXUIElement) -> String {
        AXBridge.attribute(kAXRoleAttribute, of: element) as? String ?? "unknown"
    }

    private static func isTextInputElement(_ element: AXUIElement, role: String) -> Bool {
        let supportedRoles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            "AXSearchField",
            "AXComboBox",
            "AXWebArea",
            "AXTextView"
        ]

        if supportedRoles.contains(role) {
            return true
        }

        return AXBridge.attribute("AXEditable", of: element) as? Bool ?? false
    }

    private static func caretRect(for element: AXUIElement, role roleStr: String) -> CGRect? {
        guard isTextInputElement(element, role: roleStr), let selectedRange = AXBridge.attribute(
            kAXSelectedTextRangeAttribute,
            of: element
        ) else {
            return nil
        }

        var caretBounds: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRange,
            &caretBounds
        ) == .success,
              let caretBounds
        else {
            return nil
        }

        var rect = CGRect.zero
        guard let caretBoundsValue = AXBridge.axValue(from: caretBounds),
              AXValueGetValue(caretBoundsValue, .cgRect, &rect),
              rect.origin.x > 0 || rect.size.width > 0
        else {
            return nil
        }

        return rect
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionAXValue = AXBridge.axValue(from: AXBridge.attribute(kAXPositionAttribute, of: element)),
              let sizeAXValue = AXBridge.axValue(from: AXBridge.attribute(kAXSizeAttribute, of: element))
        else {
            return nil
        }
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAXValue, .cgPoint, &origin),
              AXValueGetValue(sizeAXValue, .cgSize, &size),
              size.width > 0,
              size.height > 0
        else {
            return nil
        }

        return CGRect(origin: origin, size: size)
    }

    private static func desktopMaxY() -> CGFloat {
        NSScreen.screens.map(\.frame.maxY).max() ?? 0
    }

    private static func convertAXRectToAppKit(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: desktopMaxY() - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    private static func screen(containingAXRect rect: CGRect) -> NSScreen? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxY = desktopMaxY()

        return NSScreen.screens.first { screen in
            let topLeftFrame = CGRect(
                x: screen.frame.minX,
                y: maxY - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            return topLeftFrame.contains(center)
        } ?? NSScreen.main
    }
}
