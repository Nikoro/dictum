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
    init(settings: AppSettings) {
        let llmEnabled = settings.llmCleanupEnabled
        self.init(
            screenshot: llmEnabled && settings.contextScreenshot,
            selectedText: settings.contextSelectedText,
            clipboard: llmEnabled && settings.contextClipboard
        )
    }
}

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
