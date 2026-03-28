import AppKit
import CoreGraphics

enum SelectedTextReader {

    /// Capture selected text from the frontmost app by simulating Cmd+C.
    /// Saves and restores the clipboard so the user doesn't notice.
    /// Called synchronously from the event tap callback.
    static func readSelectedText() -> String? {
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

        // Wait for clipboard to update
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
}
