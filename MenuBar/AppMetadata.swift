import AppKit

let dictumAppVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

private var iconCache: [String: NSImage] = [:]

func applicationIcon(forBundleId bundleId: String) -> NSImage? {
    if let cached = iconCache[bundleId] { return cached }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
    let icon = NSWorkspace.shared.icon(forFile: url.path)
    iconCache[bundleId] = icon
    return icon
}
