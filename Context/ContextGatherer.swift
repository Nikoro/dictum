import AppKit

struct ContextOptions: Sendable {
    let screenshot: Bool
    let selectedText: Bool
    let clipboard: Bool

    var isEmpty: Bool {
        !screenshot && !selectedText && !clipboard
    }
}

@MainActor
extension ContextOptions {
    // Edge case: screenshot and clipboard only feed the LLM, so they are skipped without it.
    // Selected text is not: it decides whether the result is copied instead of pasted over it.
    init(settings: AppSettings) {
        let llmEnabled = settings.llmCleanupEnabled
        self.init(
            screenshot: llmEnabled && settings.contextScreenshot,
            selectedText: settings.contextSelectedText,
            clipboard: llmEnabled && settings.contextClipboard
        )
    }
}

// Edge case: NSRunningApplication is not Sendable and the frontmost app may change mid-dictation,
// so the target is snapshotted into this value at recording start.
struct TargetApp: Sendable {
    let pid: pid_t
    let name: String?
    let bundleId: String?
}

enum ContextGatherer {
    static func gather(
        selectedText: String?,
        targetApp: TargetApp?,
        options: ContextOptions,
        ocrLanguages: [String]
    ) async -> DictationContext {
        // Edge case: the clipboard is read first and synchronously, before the pipeline's own
        // paste starts mutating it.
        let (clipText, clipImage): (String?, CGImage?) = options.clipboard
            ? readClipboard()
            : (nil, nil)

        var screenshot: CGImage?
        var ocrText: String?
        if options.screenshot, let pid = targetApp?.pid {
            (screenshot, ocrText) = await Task.detached(priority: .userInitiated) {
                guard let img = await ScreenshotCapture.captureWindow(ownedBy: pid) else {
                    return (nil, nil)
                }
                return (img, ScreenshotOCR.extractText(from: img, languagesMostLikelyFirst: ocrLanguages))
            }.value
        }

        return DictationContext(
            appName: targetApp?.name,
            selectedText: options.selectedText ? selectedText : nil,
            screenshot: screenshot,
            ocrText: ocrText,
            clipboardText: clipText,
            clipboardImage: clipImage
        )
    }

    private static func readClipboard() -> (String?, CGImage?) {
        let pasteboard = NSPasteboard.general
        let text = pasteboard.string(forType: .string)

        var image: CGImage?
        if let tiffData = pasteboard.data(forType: .tiff),
           let nsImage = NSImage(data: tiffData),
           let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        {
            image = cgImage
        } else if let pngData = pasteboard.data(forType: .png),
                  let nsImage = NSImage(data: pngData),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        {
            image = cgImage
        }

        return (text, image)
    }
}
