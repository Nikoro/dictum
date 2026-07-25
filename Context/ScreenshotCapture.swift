import ScreenCaptureKit
import AppKit

enum ScreenshotCapture {

    /// Capture the main window of `pid` as a CGImage using ScreenCaptureKit.
    /// - Parameter pid: the app that was frontmost when recording *started*. Reading the
    ///   frontmost app here instead would capture whatever happens to be in front by the
    ///   time the pipeline gets around to taking the screenshot.
    /// Returns nil if Screen Recording permission is not granted or capture fails.
    static func captureWindow(ownedBy pid: pid_t) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            // Find the first on-screen window owned by the frontmost app (layer 0 = normal window)
            guard let window = content.windows.first(where: {
                $0.owningApplication?.processID == pid && $0.windowLayer == 0
            }) else { return nil }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()

            // Downscale for VLM: cap longest side at 2048px, preserve aspect ratio.
            // `window.frame` is in points but SCStreamConfiguration sizes are in pixels,
            // so fold in the backing scale factor before applying the cap.
            let maxDimension: CGFloat = 2048
            let backingScale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2 }
            let pixelWidth = window.frame.width * backingScale
            let pixelHeight = window.frame.height * backingScale
            guard pixelWidth > 0, pixelHeight > 0 else { return nil }
            let scale = min(maxDimension / max(pixelWidth, pixelHeight), 1.0)
            config.width = max(1, Int(pixelWidth * scale))
            config.height = max(1, Int(pixelHeight * scale))
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
