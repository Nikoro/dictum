import Foundation
import Sparkle

@MainActor
final class SparkleUpdateController: ObservableObject {
    static let shared = SparkleUpdateController()

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
