import SwiftUI
import AppKit

// MARK: - Floating Indicator View

struct FloatingIndicatorView: View {
    let audioRecorder: AudioRecorder
    @ObservedObject var settings: AppSettings
    let appIcon: NSImage

    @State private var levels: [Float] = Array(repeating: 0, count: 16)
    @State private var smoothedLevel: Float = 0
    @State private var dotCount: Int = 0
    @State private var dotTimer: Timer?

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { context in
            HStack(spacing: 8) {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)

                switch settings.appState {
                case .recording:
                    recordingContent(time: context.date.timeIntervalSince1970)
                case .warmingUp:
                    animatedTextContent(key: "pill.warmingUp")
                case .transcribing, .processingLLM:
                    animatedTextContent(key: "pill.transcribing")
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.35), in: .capsule)
            .glassEffect(.regular, in: .capsule)
            .onChange(of: context.date) { _, _ in
                if settings.appState == .recording {
                    sampleLevel()
                }
            }
        }
    }

    private func recordingContent(time: Double) -> some View {
        HStack(spacing: 2.5) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white)
                    .frame(width: 3, height: barHeight(for: level, index: index, time: time))
            }
        }
        .frame(height: 24)
    }

    private func animatedTextContent(key: String.LocalizationValue) -> some View {
        let base = String(localized: key)
        let dots = String(repeating: ".", count: dotCount + 1)
        let pad = String(repeating: " ", count: 3 - (dotCount + 1))
        return Text(base + dots + pad)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .fixedSize()
            .onAppear { startDotAnimation() }
            .onDisappear { stopDotAnimation() }
    }

    private func startDotAnimation() {
        guard dotTimer == nil else { return }
        dotCount = 0
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            DispatchQueue.main.async {
                dotCount = (dotCount + 1) % 3
            }
        }
    }

    private func stopDotAnimation() {
        dotTimer?.invalidate()
        dotTimer = nil
    }

    private func sampleLevel() {
        let raw = audioRecorder.audioLevel
        let db = 20 * log10(max(raw, 0.0001))
        let normalized = max(0, (db + 50) / 50)
        let boosted = pow(normalized, 0.7)
        smoothedLevel = smoothedLevel * 0.5 + Float(boosted) * 0.5
        levels.removeFirst()
        levels.append(smoothedLevel)
    }

    private func barHeight(for level: Float, index: Int, time: Double) -> CGFloat {
        let minH: CGFloat = 3
        let maxH: CGFloat = 20
        let phase = Double(index) * 0.4
        let wave = sin(time * 6 + phase) * 0.15 + 0.85
        let center = abs(Double(index) - 7.5) / 7.5
        let centerBoost = 1.0 - center * 0.3
        let h = minH + CGFloat(level) * CGFloat(wave * centerBoost) * (maxH - minH)
        return max(minH, h)
    }
}

// MARK: - Manager

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
        let view = FloatingIndicatorView(audioRecorder: audioRecorder, settings: AppSettings.shared, appIcon: icon)
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
