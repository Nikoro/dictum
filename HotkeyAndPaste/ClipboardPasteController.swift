import AppKit
import CoreGraphics

@MainActor
final class ClipboardPasteController {
    static let shared = ClipboardPasteController()

    /// Delay before simulating Cmd+V to ensure clipboard is ready
    private let clipboardSettleDelay: Duration = .milliseconds(150)
    /// Delay before restoring original clipboard after paste is processed by target app
    private let clipboardRestoreDelay: Duration = .milliseconds(500)

    private var pasteTask: Task<Void, Never>?

    private init() {}

    func pasteText(_ text: String) {
        pasteTask?.cancel()

        let pasteboard = NSPasteboard.general

        // 1. Save current clipboard
        var savedContents: [(NSPasteboard.PasteboardType, Data)] = []
        for item in pasteboard.pasteboardItems ?? [] {
            for type in item.types {
                if let data = item.data(forType: type) {
                    savedContents.append((type, data))
                }
            }
        }

        // 2. Set our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Simulate Cmd+V after short delay, then restore
        pasteTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: clipboardSettleDelay)
            guard !Task.isCancelled else { return }

            simulatePaste()

            try? await Task.sleep(for: clipboardRestoreDelay)
            guard !Task.isCancelled else { return }

            if !savedContents.isEmpty {
                pasteboard.clearContents()
                for (type, data) in savedContents {
                    pasteboard.setData(data, forType: type)
                }
            }
        }
    }

    private func simulatePaste() {
        guard AXIsProcessTrusted() else {
            dlog("[Paste] accessibility not trusted, cannot paste")
            return
        }

        let source = CGEventSource(stateID: .privateState)

        // Send all 4 events: Cmd↓, V↓, V↑, Cmd↑
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.command, keyDown: true)
        let vDown   = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.v, keyDown: true)
        let vUp     = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.v, keyDown: false)
        let cmdUp   = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.command, keyDown: false)

        cmdDown?.flags = .maskCommand
        vDown?.flags   = .maskCommand
        vUp?.flags     = .maskCommand

        cmdDown?.post(tap: .cgAnnotatedSessionEventTap)
        vDown?.post(tap: .cgAnnotatedSessionEventTap)
        vUp?.post(tap: .cgAnnotatedSessionEventTap)
        cmdUp?.post(tap: .cgAnnotatedSessionEventTap)

        dlog("[Paste] Cmd+V posted")
    }
}
