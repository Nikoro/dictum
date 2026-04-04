import CoreGraphics

struct DictationContext: Sendable {
    let appName: String?
    let bundleId: String?
    let selectedText: String?
    let screenshot: CGImage?
}
