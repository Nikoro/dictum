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
                let iconAvailability = targetAppIcon != nil ? "yes" : "nil"
                dlog(
                    "[Pill] captured app: \(app.localizedName ?? "?"), " +
                    "icon: \(iconAvailability), " +
                    "anchor=\(targetAnchor.kind.rawValue):\(targetAnchor.role)"
                )
            } else {
                dlog("[Pill] captured app: \(app.localizedName ?? "?"), icon: \(targetAppIcon != nil ? "yes" : "nil"), anchor=nil")
            }
        }
    }

    func show(audioRecorder: AudioRecorder) {
        let icon = targetAppIcon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
        dlog("[Pill] showing with icon size: \(icon.size), reps: \(icon.representations.count)")
        let view = FloatingIndicatorView(audioRecorder: audioRecorder, runtimeState: AppRuntimeState.shared, appIcon: icon)

        if let panel, let hostingView {
            hostingView.rootView = view
            let origin = caretOrigin(panelSize: panel.frame.size)
            panel.setFrameOrigin(origin)
            panel.orderFrontRegardless()
            return
        }

        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = [.intrinsicContentSize]

        let panelSize = NSSize(width: 210, height: 44)

        let newPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.level = .floating
        newPanel.hasShadow = true
        newPanel.ignoresMouseEvents = true
        newPanel.isMovableByWindowBackground = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        hosting.frame = NSRect(origin: .zero, size: panelSize)
        newPanel.contentView = hosting

        let origin = caretOrigin(panelSize: panelSize)
        newPanel.setFrameOrigin(origin)

        newPanel.orderFrontRegardless()
        self.panel = newPanel
        self.hostingView = hosting
    }

    func hide() {
        panel?.orderOut(nil)
        self.targetAnchor = nil
    }

    /// Get caret (text cursor) position via Accessibility API.
    /// Falls back to the focused input frame, then to mouse position.
    private func caretOrigin(panelSize: NSSize) -> NSPoint {
        if let anchor = targetAnchor ?? TextInputAnchorResolver.resolve(preferredPID: targetPID),
           let origin = TextInputAnchorResolver.panelOrigin(for: anchor, panelSize: panelSize) {
            let anchorDescription = "\(anchor.rect.origin.x),\(anchor.rect.origin.y),\(anchor.rect.size.width),\(anchor.rect.size.height)"
            let originDescription = "\(origin.x),\(origin.y)"
            dlog(
                "[Pill] \(anchor.kind.rawValue) role=\(anchor.role) " +
                "ax=(\(anchorDescription)) → appKit=(\(originDescription))"
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
