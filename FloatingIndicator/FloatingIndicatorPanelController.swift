import AppKit
import SwiftUI

@MainActor
final class FloatingIndicatorPanelController {
    static let shared = FloatingIndicatorPanelController()
    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingIndicatorView>?
    private var targetPID: pid_t = 0
    private var targetAppIcon: NSImage?
    private var targetAnchor: TextInputAnchorResolver.Anchor?
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
            targetAnchor = TextInputAnchorResolver.resolve(preferredPID: targetPID)
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
        if let anchor = targetAnchor ?? TextInputAnchorResolver.resolve(preferredPID: targetPID),
           let origin = TextInputAnchorResolver.panelOrigin(for: anchor, panelSize: panelSize) {
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
}
