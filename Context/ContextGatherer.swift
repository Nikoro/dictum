import AppKit

/// Which context sources to gather. Resolved on MainActor before calling `gather()`.
struct ContextOptions: Sendable {
    let screenshot: Bool
    let selectedText: Bool
    let clipboard: Bool
}

enum ContextGatherer {

    /// Gather all enabled context sources in parallel.
    /// - Parameters:
    ///   - selectedText: Already captured synchronously from the event tap (nil if nothing selected)
    ///   - frontmostApp: Already captured at recording start
    ///   - options: Which context sources are enabled
    static func gather(
        selectedText: String?,
        frontmostApp: NSRunningApplication?,
        options: ContextOptions
    ) async -> DictationContext {
        // Screenshot + OCR — parallel capture, OCR runs sequentially after capture in same Task
        let (screenshot, ocrText): (CGImage?, String?) = options.screenshot
            ? await Task.detached(priority: .userInitiated) {
                guard let img = await ScreenshotCapture.captureFrontmostWindow() else {
                    return (nil, nil)
                }
                let text = await ScreenshotOCR.extractText(from: img)
                return (img, text)
            }.value
            : (nil, nil)

        // Clipboard — read before pipeline mutates it
        let (clipText, clipImage): (String?, CGImage?) = options.clipboard
            ? readClipboard()
            : (nil, nil)

        return DictationContext(
            appName: frontmostApp?.localizedName,
            bundleId: frontmostApp?.bundleIdentifier,
            selectedText: options.selectedText ? selectedText : nil,
            screenshot: screenshot,
            ocrText: ocrText,
            clipboardText: clipText,
            clipboardImage: clipImage
        )
    }

    /// Read text and/or image from the system clipboard.
    private static func readClipboard() -> (String?, CGImage?) {
        let pb = NSPasteboard.general
        let text = pb.string(forType: .string)

        var image: CGImage?
        if let tiffData = pb.data(forType: .tiff),
           let nsImage = NSImage(data: tiffData),
           let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            image = cgImage
        } else if let pngData = pb.data(forType: .png),
                  let nsImage = NSImage(data: pngData),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            image = cgImage
        }

        return (text, image)
    }
}
