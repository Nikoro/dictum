import SwiftUI

/// NSTextView that draws placeholder when empty and ghost completion after `{{`
class GhostTextView: NSTextView {
    var placeholder: String = ""

    private let ghostColor = NSColor.secondaryLabelColor.withAlphaComponent(0.4)

    /// Compute ghost suffix based on text before cursor
    var computedGhostSuffix: String? {
        let cursorLocation = selectedRange().location
        guard cursorLocation > 0 else { return nil }
        let textBefore = (string as NSString).substring(to: cursorLocation)
        if textBefore.hasSuffix("{{") { return "text}}" }
        return nil
    }

    /// Accept ghost: insert at cursor position
    func acceptGhost() {
        guard let ghost = computedGhostSuffix else { return }
        let range = selectedRange()
        insertText(ghost, replacementRange: range)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw placeholder when empty — aligned with insertion point
        if string.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: ghostColor
            ]
            let origin = textContainerOrigin
            let inset = textContainer?.lineFragmentPadding ?? 0
            let point = NSPoint(x: origin.x + inset, y: origin.y)
            (placeholder as NSString).draw(at: point, withAttributes: attrs)
        }

        // Draw ghost suffix inline at cursor position
        if let ghost = computedGhostSuffix, let lm = layoutManager {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: ghostColor
            ]
            let cursorLocation = selectedRange().location
            let glyphIndex = lm.glyphIndexForCharacter(at: max(cursorLocation - 1, 0))
            let lineRect = lm.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let locInLine = lm.location(forGlyphAt: glyphIndex)
            let charBeforeCursor = (string as NSString).substring(with: NSRange(location: cursorLocation - 1, length: 1))
            let charSize = (charBeforeCursor as NSString).size(withAttributes: [
                .font: font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            ])
            let x = lineRect.origin.x + locInLine.x + charSize.width + textContainerInset.width
            let y = lineRect.origin.y + textContainerInset.height
            (ghost as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
        }
    }

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        needsDisplay = true
    }
}

/// SwiftUI wrapper for GhostTextView
struct PromptTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = GhostTextView()
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.placeholder = placeholder
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? GhostTextView else { return }

        textView.placeholder = placeholder

        // Sync binding → NSTextView when text changed externally
        if textView.string != text {
            textView.string = text
            textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            textView.needsDisplay = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: GhostTextView?

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            textView.needsDisplay = true
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)),
               let ghostView = textView as? GhostTextView,
               ghostView.computedGhostSuffix != nil {
                ghostView.acceptGhost()
                return true
            }
            return false
        }
    }
}
