import Foundation
import Sparkle

@MainActor
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()

    private let updaterController: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
