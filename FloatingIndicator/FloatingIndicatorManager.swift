import AppKit

@MainActor
final class FloatingIndicatorManager {
    private enum TextAnchorKind: String {
        case caret
        case focusedElement
    }

    private struct TextAnchor {
        let rect: CGRect
        let role: String
        let kind: TextAnchorKind
    }

    static let shared = FloatingIndicatorManager()
    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingIndicatorView>?
    private var targetPID: pid_t = 0
    private var targetAppIcon: NSImage?
    private var targetAnchor: TextAnchor?
    private init() {}

    /// Call before showing to capture which app the user is typing in.
    func captureTargetApp() {
        if let app = NSWorkspace.shared.frontmostApplication {
            targetPID = app.processIdentifier
            if let bundleURL = app.bundleURL {
                targetAppIcon = NSWorkspace.shared.icon(forFile: bundleURL.path)
            } else {
                targetAppIcon = app.icon
            }
            targetAnchor = Self.textAnchor(preferredPID: targetPID)
            if let targetAnchor {
                dlog(
                    "[Pill] captured app: \(app.localizedName ?? "?"), icon: \(targetAppIcon != nil ? "yes" : "nil"), anchor=\(targetAnchor.kind.rawValue):\(targetAnchor.role)"
                )
            } else {
                dlog("[Pill] captured app: \(app.localizedName ?? "?"), icon: \(targetAppIcon != nil ? "yes" : "nil"), anchor=nil")
            }
        }
    }

    func show(audioRecorder: AudioRecorder) {
        guard panel == nil else { return }

        let icon = targetAppIcon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
        dlog("[Pill] showing with icon size: \(icon.size), reps: \(icon.representations.count)")
        let view = FloatingIndicatorView(audioRecorder: audioRecorder, runtimeState: AppRuntimeState.shared, appIcon: icon)
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = [.intrinsicContentSize]

        let panelSize = NSSize(width: 210, height: 44)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        hosting.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = hosting

        let origin = caretOrigin(panelSize: panelSize)
        panel.setFrameOrigin(origin)

        panel.orderFrontRegardless()
        self.panel = panel
        self.hostingView = hosting
    }

    func hide() {
        guard let panel else { return }
        panel.orderOut(nil)
        self.panel = nil
        self.hostingView = nil
        self.targetAnchor = nil
    }

    /// Get caret (text cursor) position via Accessibility API.
    /// Falls back to the focused input frame, then to mouse position.
    private func caretOrigin(panelSize: NSSize) -> NSPoint {
        if let anchor = targetAnchor ?? Self.textAnchor(preferredPID: targetPID),
           let screen = Self.screen(containingAXRect: anchor.rect) {
            let anchorRect = Self.convertAXRectToAppKit(anchor.rect)
            let origin = Self.panelOrigin(for: anchorRect, kind: anchor.kind, panelSize: panelSize, screenFrame: screen.visibleFrame)
            dlog(
                "[Pill] \(anchor.kind.rawValue) role=\(anchor.role) ax=(\(anchor.rect.origin.x),\(anchor.rect.origin.y),\(anchor.rect.size.width),\(anchor.rect.size.height)) → appKit=(\(origin.x),\(origin.y))"
            )
            return origin
        }

        // Fallback: mouse position
        let mouse = NSEvent.mouseLocation
        dlog("[Pill] no caret, using mouse=(\(mouse.x),\(mouse.y))")
        return NSPoint(
            x: mouse.x - panelSize.width / 2,
            y: mouse.y - panelSize.height - 16
        )
    }

    private static func focusedElement(in application: AXUIElement) -> AXUIElement? {
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }

        return focusedElement as! AXUIElement
    }

    private static func systemWideFocusedElement() -> AXUIElement? {
        focusedElement(in: AXUIElementCreateSystemWide())
    }

    private static func textAnchor(preferredPID: pid_t) -> TextAnchor? {
        // Prefer the system-wide focused element first because Electron/web inputs
        // often expose usable AX state there even when the target app chain is sparse.
        if let focusedElement = systemWideFocusedElement(), let anchor = textAnchor(from: focusedElement) {
            return anchor
        }

        guard preferredPID > 0,
              let focusedElement = focusedElement(in: AXUIElementCreateApplication(preferredPID)) else {
            return nil
        }

        return textAnchor(from: focusedElement)
    }

    private static func textAnchor(from startingElement: AXUIElement) -> TextAnchor? {
        // Walk ancestors because many apps expose caret bounds on a parent text container,
        // not on the immediately focused AX node.
        for element in ancestorChain(startingAt: startingElement, limit: 8) {
            let role = role(of: element)
            if let caretRect = caretRect(for: element) {
                return TextAnchor(rect: caretRect, role: role, kind: .caret)
            }
            if isTextInputElement(element, role: role), let elementRect = frame(of: element) {
                return TextAnchor(rect: elementRect, role: role, kind: .focusedElement)
            }
        }

        return nil
    }

    private static func ancestorChain(startingAt element: AXUIElement, limit: Int) -> [AXUIElement] {
        var chain: [AXUIElement] = []
        var current: AXUIElement? = element

        while let node = current, chain.count < limit {
            chain.append(node)
            current = parent(of: node)
        }

        return chain
    }

    private static func parent(of element: AXUIElement) -> AXUIElement? {
        var parent: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent) == .success else {
            return nil
        }

        return parent as! AXUIElement
    }

    private static func role(of element: AXUIElement) -> String {
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        return role as? String ?? "unknown"
    }

    private static func isTextInputElement(_ element: AXUIElement, role: String) -> Bool {
        let supportedRoles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            "AXSearchField",
            "AXComboBox",
            "AXWebArea",
            "AXTextView"
        ]

        if supportedRoles.contains(role) {
            return true
        }

        return boolAttribute("AXEditable" as CFString, on: element) == true
    }

    private static func boolAttribute(_ attribute: CFString, on element: AXUIElement) -> Bool? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? Bool
    }

    /// Query the focused text element's caret position via AX API.
    private static func caretRect(for element: AXUIElement) -> CGRect? {
        let roleStr = role(of: element)

        guard isTextInputElement(element, role: roleStr) else {
            return nil
        }

        var selectedRange: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange) == .success else {
            return nil
        }

        var caretBounds: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRange!,
            &caretBounds
        ) == .success else {
            return nil
        }

        var rect = CGRect.zero
        // AXValue is a CF type — cast always succeeds after .success check
        guard AXValueGetValue(caretBounds as! AXValue, .cgRect, &rect) else {
            return nil
        }

        // Validate — x=0 with non-zero y is likely a bogus result
        guard rect.origin.x > 0 || rect.size.width > 0 else {
            return nil
        }

        return rect
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?

        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              positionValue != nil,
              sizeValue != nil else {
            return nil
        }

          let positionAXValue = positionValue as! AXValue
          let sizeAXValue = sizeValue as! AXValue
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAXValue, .cgPoint, &origin),
              AXValueGetValue(sizeAXValue, .cgSize, &size),
              size.width > 0,
              size.height > 0 else {
            return nil
        }

        return CGRect(origin: origin, size: size)
    }

    private static func desktopMaxY() -> CGFloat {
        NSScreen.screens.map(\.frame.maxY).max() ?? 0
    }

    private static func convertAXRectToAppKit(_ rect: CGRect) -> CGRect {
        // AX uses a top-left style desktop coordinate space, while AppKit panels are
        // placed in bottom-left space. Use the desktop max Y to stay correct on multi-display setups.
        CGRect(
            x: rect.origin.x,
            y: desktopMaxY() - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    private static func screen(containingAXRect rect: CGRect) -> NSScreen? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let desktopMaxY = desktopMaxY()

        return NSScreen.screens.first { screen in
            let topLeftFrame = CGRect(
                x: screen.frame.minX,
                y: desktopMaxY - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            return topLeftFrame.contains(center)
        } ?? NSScreen.main
    }

    private static func panelOrigin(for anchorRect: CGRect, kind: TextAnchorKind, panelSize: NSSize, screenFrame: CGRect) -> NSPoint {
        let spacing: CGFloat = 8
        let preferredLeftX = anchorRect.minX - panelSize.width - spacing
        let fallbackRightX = anchorRect.maxX + spacing
        var x = preferredLeftX
        var y = kind == .caret
            ? anchorRect.minY - (panelSize.height - anchorRect.height) / 2
            : anchorRect.midY - panelSize.height / 2

        if preferredLeftX < screenFrame.minX {
            x = fallbackRightX
        }

        x = max(x, screenFrame.minX)
        x = min(x, screenFrame.maxX - panelSize.width)
        y = max(y, screenFrame.minY)
        y = min(y, screenFrame.maxY - panelSize.height)

        return NSPoint(x: x, y: y)
    }
}
