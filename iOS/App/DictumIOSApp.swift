import SwiftUI

@main
struct DictumIOSApp: App {
    @State private var dictation = DictationSession()
    @State private var returnTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DictationView(dictation: dictation)
                .task { await activateIfRunningNormally() }
                .onChange(of: scenePhase) {
                    if scenePhase == .active {
                        Task { await activateIfRunningNormally() }
                    }
                }
                .onOpenURL { url in
                    guard url.scheme == "dictum", url.host == "session" else { return }
                    resumeFromKeyboard(url)
                }
        }
    }

    private func resumeFromKeyboard(_ url: URL) {
        returnTask?.cancel()
        returnTask = Task {
            await KeyboardHostReturn.perform(
                activation: url,
                isForeground: { foregroundSceneIsActive },
                isReady: { dictation.isActive && !dictation.isSuspended },
                activate: prepareReturn,
                open: openHost
            )
        }
    }

    private func openHost(_ destination: URL) async {
        await UIApplication.shared.open(
            destination,
            options: destination.scheme == "https" ? [.universalLinksOnly: true] : [:]
        )
    }

    private func prepareReturn() async -> Bool {
        await dictation.setMicrophoneEnabled(true)
        let deadline = ContinuousClock.now.advanced(by: .seconds(120))
        while dictation.preparing || dictation.starting {
            guard ContinuousClock.now < deadline else { return false }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return false }
        }
        return dictation.isActive && !dictation.isSuspended
    }

    private var foregroundSceneIsActive: Bool {
        UIApplication.shared.connectedScenes.contains { $0.activationState == .foregroundActive }
    }

    private func activateIfRunningNormally() async {
        #if DEBUG
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
        #endif
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              NSClassFromString("XCTestCase") == nil,
              foregroundSceneIsActive else { return }
        await dictation.activate()
    }
}
