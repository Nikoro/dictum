import SwiftUI

@MainActor
struct FooterSection: View {
    @Environment(AppRuntimeState.self) private var runtimeState
    @Environment(SparkleUpdateController.self) private var updateController
    @State private var showUninstallAlert = false

    var body: some View {
        VStack(spacing: 8) {
            if case let .error(message) = runtimeState.appState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            controls
        }
        .padding()
        .alert(
            String(localized: "uninstall.title", defaultValue: "Uninstall Dictum?"),
            isPresented: $showUninstallAlert
        ) {
            Button(String(localized: "uninstall.cancel", defaultValue: "Cancel"), role: .cancel) {}
            Button(String(localized: "uninstall.confirm", defaultValue: "Uninstall"), role: .destructive) {
                performUninstall()
            }
        } message: {
            Text(
                String(
                    localized: "uninstall.message",
                    defaultValue: """
                    This will delete all downloaded models, settings, and move Dictum to Trash. \
                    This cannot be undone.
                    """
                )
            )
        }
    }

    private var controls: some View {
        HStack {
            Button(action: { NSApplication.shared.terminate(nil) }, label: {
                Image(systemName: "power")
            })
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "a11y.quit", defaultValue: "Quit Dictum"))
            .foregroundStyle(.secondary)
            .font(.caption)

            Spacer()

            Button(action: { updateController.checkForUpdates() }, label: {
                Text(String(format: String(localized: "footer.version", defaultValue: "Version: %@"), dictumAppVersion))
                    .font(.caption)
                    .foregroundStyle(updateController.canCheckForUpdates ? Color("AccentColor") : .secondary)
                    .underline(updateController.canCheckForUpdates)
            })
            .buttonStyle(.plain)
            .disabled(!updateController.canCheckForUpdates)
            .help(String(localized: "footer.checkUpdates", defaultValue: "Check for updates"))

            Spacer()

            Button(action: { showUninstallAlert = true }, label: {
                Image(systemName: "trash")
            })
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "a11y.uninstall", defaultValue: "Uninstall Dictum"))
            .foregroundStyle(.secondary)
            .font(.caption)
        }
    }

    private func performUninstall() {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser

        LLMModelStorage.deleteAll()
        WhisperModelStorage.standard.deleteAll()
        for variant in ParakeetVariant.allCases {
            try? fileManager.removeItem(at: variant.directory)
        }

        let appCacheDir = homeDirectory.appendingPathComponent("Library/Caches/com.dominikkrajcer.dictum")
        try? fileManager.removeItem(at: appCacheDir)

        let logDir = homeDirectory.appendingPathComponent("Library/Logs/Dictum")
        try? fileManager.removeItem(at: logDir)

        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }

        if let appURL = Bundle.main.bundleURL as URL? {
            try? fileManager.trashItem(at: appURL, resultingItemURL: nil)
        }

        NSApplication.shared.terminate(nil)
    }
}
