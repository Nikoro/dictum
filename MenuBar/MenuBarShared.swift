import AppKit

let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

func appIcon(forBundleId bundleId: String) -> NSImage? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
    return NSWorkspace.shared.icon(forFile: url.path)
}
