import AppKit
import CoreGraphics

enum SelectedTextCapture {

    /// Capture selected text from the frontmost app by simulating Cmd+C.
    /// Saves and restores the clipboard so the user doesn't notice.
    /// Called synchronously from the event tap callback.
    static func readSelectedText() -> String? {
        guard let focusedElement = focusedElement(),
              let selectedRange = selectedTextRange(for: focusedElement),
              selectedRange.length > 0 else {
            dlog("[SelectedText] no accessibility selection")
            return nil
        }

        if let accessibilityText = selectedText(for: focusedElement), !accessibilityText.isEmpty {
            dlog("[SelectedText] got \(accessibilityText.count) chars from AX")
            return accessibilityText
        }

        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount

        // Save current clipboard contents
        let savedItems = pasteboard.pasteboardItems?.flatMap { item in
            item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        } ?? []

        // Simulate Cmd+C
        let src = CGEventSource(stateID: .privateState)
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false) else {
            dlog("[SelectedText] failed to create CGEvent")
            return nil
        }
        keyDown.flags = CGEventFlags.maskCommand
        keyUp.flags = CGEventFlags.maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        // This synchronous wait is why callers must never run this on the event tap thread itself.
        // The hotkey monitor hops to a background queue first so the synthetic Cmd+C can be delivered.
        Thread.sleep(forTimeInterval: 0.05)

        let text: String?
        if pasteboard.changeCount != changeCount {
            text = pasteboard.string(forType: .string)
            dlog("[SelectedText] got \(text?.count ?? 0) chars")
        } else {
            dlog("[SelectedText] clipboard unchanged (no selection)")
            text = nil
        }

        // Restore original clipboard
        pasteboard.clearContents()
        for (type, data) in savedItems {
            pasteboard.setData(data, forType: type)
        }

        guard let text, !text.isEmpty else { return nil }
        return text
    }

    private static func focusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }

        return (focusedElement as! AXUIElement)
    }

    private static func selectedTextRange(for element: AXUIElement) -> CFRange? {
        var selectedRangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success,
              selectedRangeValue != nil else {
            return nil
        }

        var selectedRange = CFRange()
        guard AXValueGetValue(selectedRangeValue as! AXValue, .cfRange, &selectedRange) else {
            return nil
        }

        return selectedRange
    }

    private static func selectedText(for element: AXUIElement) -> String? {
        var selectedText: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText) == .success else {
            return nil
        }

        return selectedText as? String
    }
}
