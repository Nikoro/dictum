import SwiftUI

@MainActor
class GhostTextView: NSTextView {
    var placeholder: String = ""

    private let ghostColor = NSColor.secondaryLabelColor.withAlphaComponent(0.4)

    private var textFont: NSFont {
        font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    }

    private var ghostAttributes: [NSAttributedString.Key: Any] {
        [.font: textFont, .foregroundColor: ghostColor]
    }

    var ghostSuffixAfterCursor: String? {
        let cursorLocation = selectedRange().location
        guard cursorLocation > 0 else { return nil }
        let textBeforeCursor = (string as NSString).substring(to: cursorLocation)
        return textBeforeCursor.hasSuffix("{{") ? "text}}" : nil
    }

    func acceptGhostSuffix() {
        guard let ghost = ghostSuffixAfterCursor else { return }
        insertText(ghost, replacementRange: selectedRange())
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty {
            drawPlaceholder()
        }
        if let ghost = ghostSuffixAfterCursor, let layoutManager {
            drawGhostSuffix(ghost, layoutManager: layoutManager)
        }
    }

    private func drawPlaceholder() {
        let origin = textContainerOrigin
        let inset = textContainer?.lineFragmentPadding ?? 0
        (placeholder as NSString).draw(at: NSPoint(x: origin.x + inset, y: origin.y), withAttributes: ghostAttributes)
    }

    private func drawGhostSuffix(_ ghost: String, layoutManager: NSLayoutManager) {
        let cursorLocation = selectedRange().location
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: max(cursorLocation - 1, 0))
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        let locationInLine = layoutManager.location(forGlyphAt: glyphIndex)
        let charBeforeCursor = (string as NSString).substring(with: NSRange(location: cursorLocation - 1, length: 1))
        let charWidth = (charBeforeCursor as NSString).size(withAttributes: [.font: textFont]).width
        let drawX = lineRect.origin.x + locationInLine.x + charWidth + textContainerInset.width
        let drawY = lineRect.origin.y + textContainerInset.height
        (ghost as NSString).draw(at: NSPoint(x: drawX, y: drawY), withAttributes: ghostAttributes)
    }

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        needsDisplay = true
    }
}

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
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? GhostTextView else { return }

        textView.placeholder = placeholder

        let textChangedOutsideEditor = textView.string != text
        if textChangedOutsideEditor {
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
               ghostView.ghostSuffixAfterCursor != nil
            {
                ghostView.acceptGhostSuffix()
                return true
            }
            return false
        }
    }
}
