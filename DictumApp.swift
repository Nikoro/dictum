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
        // Edge case: unit tests run inside the app as their host; starting the event tap, the menu
        // bar and model preloading there would race the tests and prompt for permissions.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
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
