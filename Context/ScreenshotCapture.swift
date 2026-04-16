import ScreenCaptureKit
import AppKit

enum ScreenshotCapture {

    /// Capture the frontmost window as a CGImage using ScreenCaptureKit.
    /// Returns nil if Screen Recording permission is not granted or capture fails.
    static func captureFrontmostWindow() async -> CGImage? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            // Find the first on-screen window owned by the frontmost app (layer 0 = normal window)
            guard let window = content.windows.first(where: {
                $0.owningApplication?.processID == pid && $0.windowLayer == 0
            }) else { return nil }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()

            // Downscale for VLM: cap longest side at 2048px, preserve aspect ratio
            let maxDimension: CGFloat = 2048
            let w = window.frame.width
            let h = window.frame.height
            let scale = min(maxDimension / max(w, h), 1.0)
            config.width = Int(w * scale)
            config.height = Int(h * scale)
            config.captureResolution = .best
            config.showsCursor = false

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            dlog("[Screenshot] capture failed: \(error.localizedDescription)")
            return nil
        }
    }
}
