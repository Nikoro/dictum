import AppKit
import CoreGraphics

@MainActor
final class ClipboardPasteController {
    static let shared = ClipboardPasteController()

    private let clipboardSettleDelay: Duration = .milliseconds(150)
    // Edge case: the target app reads the pasteboard asynchronously after Cmd+V; restoring the
    // user's clipboard sooner pastes their old contents instead.
    private let clipboardRestoreDelay: Duration = .milliseconds(500)

    private var pasteTask: Task<Void, Never>?

    private init() {}

    func pasteText(_ text: String) {
        pasteTask?.cancel()

        let pasteboard = NSPasteboard.general
        let savedContents = PasteboardSnapshot(of: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        pasteTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: clipboardSettleDelay)
            guard !Task.isCancelled else { return }

            simulatePaste()

            try? await Task.sleep(for: clipboardRestoreDelay)
            guard !Task.isCancelled, !savedContents.isEmpty else { return }
            savedContents.restore(to: pasteboard)
        }
    }

    private func simulatePaste() {
        guard AXIsProcessTrusted() else {
            dlog("[Paste] accessibility not trusted, cannot paste")
            return
        }

        let source = CGEventSource(stateID: .privateState)

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.command, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.letterV, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.letterV, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: KeyCode.command, keyDown: false)

        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        cmdDown?.post(tap: .cgAnnotatedSessionEventTap)
        vDown?.post(tap: .cgAnnotatedSessionEventTap)
        vUp?.post(tap: .cgAnnotatedSessionEventTap)
        cmdUp?.post(tap: .cgAnnotatedSessionEventTap)

        dlog("[Paste] Cmd+V posted")
    }
}
