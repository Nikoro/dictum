import AppKit
import CoreGraphics

enum SelectedTextCapture {
    static func readSelectedText() -> String? {
        guard let focusedElement = AXBridge.focusedElement(),
              let selectedRange = AXBridge.selectedTextRange(of: focusedElement),
              selectedRange.length > 0
        else {
            dlog("[SelectedText] no accessibility selection")
            return nil
        }

        if let accessibilityText = AXBridge.attribute(kAXSelectedTextAttribute, of: focusedElement) as? String,
           !accessibilityText.isEmpty
        {
            dlog("[SelectedText] got \(accessibilityText.count) chars from AX")
            return accessibilityText
        }

        return copySelectionViaKeystroke()
    }

    // Edge case: some apps expose a selection range over Accessibility but not its text.
    private static func copySelectionViaKeystroke() -> String? {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        let savedContents = PasteboardSnapshot(of: pasteboard)

        guard postCommandC() else {
            dlog("[SelectedText] failed to create CGEvent")
            return nil
        }

        // Edge case: never call this on the event tap thread; the synthetic Cmd+C is delivered
        // through that thread, so blocking it here would wait forever.
        Thread.sleep(forTimeInterval: 0.05)

        guard pasteboard.changeCount != changeCount else {
            dlog("[SelectedText] clipboard unchanged (no selection)")
            return nil
        }
        let text = pasteboard.string(forType: .string)
        dlog("[SelectedText] got \(text?.count ?? 0) chars")
        savedContents.restore(to: pasteboard, ifUnchangedSince: pasteboard.changeCount)

        guard let text, !text.isEmpty else { return nil }
        return text
    }

    private static func postCommandC() -> Bool {
        let source = CGEventSource(stateID: .privateState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.letterC, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.letterC, keyDown: false)
        else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        return true
    }
}
