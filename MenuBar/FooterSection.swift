import SwiftUI

@MainActor
struct FooterSection: View {
    @EnvironmentObject var runtimeState: AppRuntimeState
    @EnvironmentObject var updateController: SparkleUpdateController
    @State private var showUninstallAlert = false

    var body: some View {
        VStack(spacing: 8) {
            if case .error(let message) = runtimeState.appState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            HStack {
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)

                Spacer()

                Button(action: { updateController.checkForUpdates() }) {
                    Text("Wersja: \(dictumAppVersion)")
                        .font(.caption)
                        .foregroundStyle(updateController.canCheckForUpdates ? Color("AccentColor") : .secondary)
                        .underline(updateController.canCheckForUpdates)
                }
                .buttonStyle(.plain)
                .disabled(!updateController.canCheckForUpdates)
                .help(String(localized: "footer.checkUpdates", defaultValue: "Sprawdź aktualizacje"))

                Spacer()

                Button(action: { showUninstallAlert = true }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
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
            Text(String(localized: "uninstall.message", defaultValue: "This will delete all downloaded models, settings, and move Dictum to Trash. This cannot be undone."))
        }
    }

    private func performUninstall() {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser

        let mlxCacheDir = homeDirectory.appendingPathComponent("Library/Caches/models")
        try? fileManager.removeItem(at: mlxCacheDir)

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
