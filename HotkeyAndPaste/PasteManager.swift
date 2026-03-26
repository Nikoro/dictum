import AppKit
import CoreGraphics

final class PasteManager {
    static let shared = PasteManager()

    private init() {}

    func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general

        // 1. Save current clipboard
        let previousItems = pasteboard.pasteboardItems?.compactMap { item -> (NSPasteboard.PasteboardType, Data)? in
            guard let types = item.types as? [NSPasteboard.PasteboardType] else { return nil }
            for type in types {
                if let data = item.data(forType: type) {
                    return (type, data)
                }
            }
            return nil
        } ?? []

        // 2. Set our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Simulate Cmd+V
        simulatePaste()

        // 4. Restore clipboard after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            if let (type, data) = previousItems.first {
                pasteboard.setData(data, forType: type)
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)

        // Key code 0x09 = V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = CGEventFlags.maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = CGEventFlags.maskCommand

        keyDown?.post(tap: CGEventTapLocation.cghidEventTap)
        keyUp?.post(tap: CGEventTapLocation.cghidEventTap)
    }
}
