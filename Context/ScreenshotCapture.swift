import AppKit
import ScreenCaptureKit

enum ScreenshotCapture {
    // Edge case: `pid` must be the app frontmost when recording started; by the time this runs
    // something else may be in front.
    static func captureWindow(ownedBy pid: pid_t) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            let normalWindowLayer = 0
            guard let window = content.windows.first(where: {
                $0.owningApplication?.processID == pid && $0.windowLayer == normalWindowLayer
            }) else { return nil }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()

            // Edge case: `window.frame` is in points but SCStreamConfiguration wants pixels.
            let maxVisionModelDimension: CGFloat = 2048
            let backingScale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2 }
            let pixelWidth = window.frame.width * backingScale
            let pixelHeight = window.frame.height * backingScale
            guard pixelWidth > 0, pixelHeight > 0 else { return nil }
            let scale = min(maxVisionModelDimension / max(pixelWidth, pixelHeight), 1.0)
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
