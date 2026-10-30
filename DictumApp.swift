import SwiftUI

@main
struct DictumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
        DictationPipeline.shared.start()
        #if DEBUG
        DebugTranscriptionHarness.runIfRequested()
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        DictationPipeline.shared.cancelOperation()
        GlobalHotkeyMonitor.shared.stop()
    }
}
