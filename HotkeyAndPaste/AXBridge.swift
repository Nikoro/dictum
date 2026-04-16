import ApplicationServices

/// Safe CF ↔ Swift bridging helpers for Accessibility types.
enum AXBridge {
    static func axUIElement(from object: AnyObject?) -> AXUIElement? {
        guard let object, CFGetTypeID(object) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(object, to: AXUIElement.self)
    }

    static func axValue(from object: AnyObject?) -> AXValue? {
        guard let object, CFGetTypeID(object) == AXValueGetTypeID() else {
            return nil
        }
        return unsafeBitCast(object, to: AXValue.self)
    }
}
