import CoreGraphics

struct DictationContext: Sendable {
    let appName: String?
    let selectedText: String?
    let screenshot: CGImage?
    let ocrText: String?
    let clipboardText: String?
    let clipboardImage: CGImage?

    var sourcesPresentWithoutContents: String {
        func flag(_ present: Bool) -> String {
            present ? "yes" : "no"
        }
        return "app=\(appName ?? "nil"), selectedText=\(flag(selectedText != nil)), " +
            "screenshot=\(flag(screenshot != nil)), " +
            "clipboard=\(flag(clipboardText != nil || clipboardImage != nil))"
    }
}
