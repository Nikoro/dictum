import ApplicationServices

enum AXBridge {
    static func axUIElement(from object: AnyObject?) -> AXUIElement? {
        guard let object, CFGetTypeID(object) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(object, to: AXUIElement.self)
    }

    static func axValue(from object: AnyObject?) -> AXValue? {
        guard let object, CFGetTypeID(object) == AXValueGetTypeID() else {
            return nil
        }
        return unsafeDowncast(object, to: AXValue.self)
    }

    static func attribute(_ name: String, of element: AXUIElement) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    static func elementAttribute(_ name: String, of element: AXUIElement) -> AXUIElement? {
        axUIElement(from: attribute(name, of: element))
    }

    static func focusedElement(in root: AXUIElement = AXUIElementCreateSystemWide()) -> AXUIElement? {
        elementAttribute(kAXFocusedUIElementAttribute, of: root)
    }

    static func selectedTextRange(of element: AXUIElement) -> CFRange? {
        var range = CFRange()
        guard let value = axValue(from: attribute(kAXSelectedTextRangeAttribute, of: element)),
              AXValueGetValue(value, .cfRange, &range)
        else {
            return nil
        }
        return range
    }
}
