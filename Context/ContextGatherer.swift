import AppKit

enum ContextGatherer {

    /// Gather all context in parallel.
    /// - Parameters:
    ///   - selectedText: Already captured synchronously from the event tap
    ///   - frontmostApp: Already captured at recording start
    static func gather(
        selectedText: String?,
        frontmostApp: NSRunningApplication?
    ) async -> DictationContext {
        let screenshot = await Task.detached(priority: .userInitiated) {
            await ScreenshotCapture.captureFrontmostWindow()
        }.value

        return DictationContext(
            appName: frontmostApp?.localizedName,
            bundleId: frontmostApp?.bundleIdentifier,
            selectedText: selectedText,
            screenshot: screenshot
        )
    }
}
