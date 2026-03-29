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
    static let shared = FloatingIndicatorManager()
    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingIndicatorView>?
    private var targetPID: pid_t = 0
    private var targetAppIcon: NSImage?
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
            dlog("[Pill] captured app: \(app.localizedName ?? "?"), icon: \(targetAppIcon != nil ? "yes" : "nil")")
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
    }

    /// Get caret (text cursor) position via Accessibility API.
    /// Falls back to mouse position if caret is unavailable.
    private func caretOrigin(panelSize: NSSize) -> NSPoint {
        if targetPID > 0, let caretRect = Self.caretRect(pid: targetPID) {
            // AX uses top-left origin; find the screen containing the caret
            let caretCenter = NSPoint(x: caretRect.midX, y: caretRect.midY)
            let screen = NSScreen.screens.first { screen in
                // Convert screen frame to top-left coords for comparison
                let mainH = NSScreen.screens.first?.frame.height ?? 900
                let topLeftFrame = NSRect(
                    x: screen.frame.origin.x,
                    y: mainH - screen.frame.origin.y - screen.frame.height,
                    width: screen.frame.width,
                    height: screen.frame.height
                )
                return topLeftFrame.contains(caretCenter)
            } ?? NSScreen.main

            let mainH = NSScreen.screens.first?.frame.height ?? 900

            // Convert AX top-left Y to AppKit bottom-left Y
            let caretAppKitY = mainH - caretRect.origin.y - caretRect.size.height
            let caretAppKitX = caretRect.origin.x

            // Position pill to the left of caret, vertically aligned
            var x = caretAppKitX - panelSize.width - 8
            var y = caretAppKitY

            // Clamp to screen bounds
            if let screenFrame = screen?.visibleFrame {
                if x < screenFrame.minX {
                    // Not enough space on left — put it above caret instead
                    x = caretAppKitX
                    y = caretAppKitY + caretRect.height + 8
                }
                x = max(x, screenFrame.minX)
                x = min(x, screenFrame.maxX - panelSize.width)
                y = max(y, screenFrame.minY)
                y = min(y, screenFrame.maxY - panelSize.height)
            }

            dlog("[Pill] caretAX=(\(caretRect.origin.x),\(caretRect.origin.y)) → appKit=(\(x),\(y))")
            return NSPoint(x: x, y: y)
        }

        // Fallback: mouse position
        let mouse = NSEvent.mouseLocation
        dlog("[Pill] no caret, using mouse=(\(mouse.x),\(mouse.y))")
        return NSPoint(
            x: mouse.x - panelSize.width / 2,
            y: mouse.y - panelSize.height - 16
        )
    }

    /// Query the focused text element's caret position via AX API.
    /// Uses the stored target PID (the app that was active when recording started).
    private static func caretRect(pid: pid_t) -> CGRect? {
        let axApp = AXUIElementCreateApplication(pid)

        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }

        // AXUIElement is a CF type — cast always succeeds after .success check
        let element = focusedElement as! AXUIElement

        // Check this is actually a text element
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleStr = role as? String ?? ""
        guard roleStr == kAXTextFieldRole as String
           || roleStr == kAXTextAreaRole as String
           || roleStr == "AXWebArea"
           || roleStr == "AXComboBox"
        else {
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
}
