import AppKit

/// Which context sources to gather. Resolved on MainActor before calling `gather()`.
struct ContextOptions: Sendable {
    let screenshot: Bool
    let selectedText: Bool
    let clipboard: Bool
}

/// The target app, snapshotted at recording start. `NSRunningApplication` is not Sendable
/// and the frontmost app may have changed by the time context is gathered, so the pipeline
/// resolves these fields up front and passes them across.
struct TargetApp: Sendable {
    let pid: pid_t
    let name: String?
    let bundleId: String?
}

enum ContextGatherer {

    /// Gather all enabled context sources.
    /// - Parameters:
    ///   - selectedText: Already captured synchronously from the event tap (nil if nothing selected)
    ///   - targetApp: Already captured at recording start
    ///   - options: Which context sources are enabled
    ///   - ocrLanguages: Recognition languages for screenshot OCR, most likely first
    static func gather(
        selectedText: String?,
        targetApp: TargetApp?,
        options: ContextOptions,
        ocrLanguages: [String]
    ) async -> DictationContext {
        // Clipboard is read first, and synchronously, so it reflects the state before the
        // pipeline's own paste handling starts mutating the pasteboard.
        let (clipText, clipImage): (String?, CGImage?) = options.clipboard
            ? readClipboard()
            : (nil, nil)

        // Screenshot capture and OCR are both slow, so they run off the main actor.
        var screenshot: CGImage?
        var ocrText: String?
        if options.screenshot, let pid = targetApp?.pid {
            (screenshot, ocrText) = await Task.detached(priority: .userInitiated) {
                guard let img = await ScreenshotCapture.captureWindow(ownedBy: pid) else {
                    return (nil, nil)
                }
                return (img, await ScreenshotOCR.extractText(from: img, languages: ocrLanguages))
            }.value
        }

        return DictationContext(
            appName: targetApp?.name,
            bundleId: targetApp?.bundleId,
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
