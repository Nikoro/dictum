import SwiftUI

/// NSTextView that draws placeholder when empty and ghost completion after `{{`
class GhostTextView: NSTextView {
    var placeholder: String = ""
    var ghostSuffix: String? {
        didSet { needsDisplay = true }
    }

    private let ghostColor = NSColor.secondaryLabelColor.withAlphaComponent(0.4)

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

        // Draw ghost suffix inline after last character
        if let ghost = ghostSuffix, !string.isEmpty, let lm = layoutManager, let tc = textContainer {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: ghostColor
            ]
            let glyphIndex = lm.glyphIndexForCharacter(at: (string as NSString).length - 1)
            var lineRect = lm.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let locInLine = lm.location(forGlyphAt: glyphIndex)
            let charSize = (String(string.last!) as NSString).size(withAttributes: [
                .font: font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            ])
            let x = lineRect.origin.x + locInLine.x + charSize.width + textContainerInset.width
            let y = lineRect.origin.y + textContainerInset.height
            (ghost as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
        }
    }
}

/// SwiftUI wrapper for GhostTextView
struct PromptTextEditor: NSViewRepresentable {
    @Binding var text: String
    let ghostSuffix: String?
    let placeholder: String
    let onTab: () -> Void

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
        textView.ghostSuffix = ghostSuffix
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? GhostTextView else { return }
        let coord = context.coordinator

        textView.placeholder = placeholder
        textView.ghostSuffix = ghostSuffix
        coord.ghostSuffix = ghostSuffix
        coord.onTab = onTab

        // Sync binding → NSTextView when text changed externally
        if textView.string != text {
            textView.string = text
            textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            textView.needsDisplay = true
        }

        if coord.didAcceptGhost {
            coord.didAcceptGhost = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onTab: onTab, ghostSuffix: ghostSuffix)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onTab: () -> Void
        var ghostSuffix: String?
        var didAcceptGhost = false
        weak var textView: GhostTextView?

        init(text: Binding<String>, onTab: @escaping () -> Void, ghostSuffix: String?) {
            self.text = text
            self.onTab = onTab
            self.ghostSuffix = ghostSuffix
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            textView.needsDisplay = true
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)), ghostSuffix != nil {
                didAcceptGhost = true
                onTab()
                return true
            }
            return false
        }
    }
}
