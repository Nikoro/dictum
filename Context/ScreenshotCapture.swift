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
            config.width = Int(window.frame.width * 2) // Retina
            config.height = Int(window.frame.height * 2)
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
