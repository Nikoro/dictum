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

    func captureTargetApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        targetPID = app.processIdentifier
        targetAppIcon = app.bundleURL.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? app.icon
        targetAnchor = TextInputAnchorResolver.resolve(preferredPID: targetPID)
        let anchorDescription = targetAnchor.map { "\($0.kind.rawValue):\($0.role)" } ?? "nil"
        dlog(
            "[Pill] captured app: \(app.localizedName ?? "?"), " +
                "icon: \(targetAppIcon != nil ? "yes" : "nil"), anchor=\(anchorDescription)"
        )
    }

    func show(audioRecorder: AudioRecorder) {
        let icon = targetAppIcon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
        dlog("[Pill] showing with icon size: \(icon.size), reps: \(icon.representations.count)")
        let view = FloatingIndicatorView(audioRecorder: audioRecorder, runtimeState: AppRuntimeState.shared, appIcon: icon)

        if let panel, let hostingView {
            hostingView.rootView = view
            panel.setFrameOrigin(panelOriginNearCaretOrMouse(panelSize: panel.frame.size))
            panel.orderFrontRegardless()
            return
        }

        let panelSize = NSSize(width: 210, height: 44)
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.frame = NSRect(origin: .zero, size: panelSize)

        let newPanel = Self.makeNonActivatingClickThroughPanel(size: panelSize)
        newPanel.contentView = hosting
        newPanel.setFrameOrigin(panelOriginNearCaretOrMouse(panelSize: panelSize))
        newPanel.orderFrontRegardless()
        panel = newPanel
        hostingView = hosting
    }

    private static func makeNonActivatingClickThroughPanel(size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
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
        return panel
    }

    func hide() {
        panel?.orderOut(nil)
        targetAnchor = nil
    }

    private func panelOriginNearCaretOrMouse(panelSize: NSSize) -> NSPoint {
        if let anchor = targetAnchor ?? TextInputAnchorResolver.resolve(preferredPID: targetPID),
           let origin = TextInputAnchorResolver.panelOrigin(for: anchor, panelSize: panelSize)
        {
            let rect = anchor.rect
            let anchorDescription = "\(rect.origin.x),\(rect.origin.y),\(rect.width),\(rect.height)"
            let originDescription = "\(origin.x),\(origin.y)"
            dlog(
                "[Pill] \(anchor.kind.rawValue) role=\(anchor.role) " +
                    "ax=(\(anchorDescription)) → appKit=(\(originDescription))"
            )
            return origin
        }

        let mouse = NSEvent.mouseLocation
        dlog("[Pill] no caret, using mouse=(\(mouse.x),\(mouse.y))")
        return NSPoint(
            x: mouse.x - panelSize.width / 2,
            y: mouse.y - panelSize.height - 16
        )
    }
}
