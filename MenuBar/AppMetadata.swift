import AppKit

let dictumAppVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

func applicationIcon(forBundleId bundleId: String) -> NSImage? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
    return NSWorkspace.shared.icon(forFile: url.path)
}
