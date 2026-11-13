import Foundation
import Observation
import Sparkle

@MainActor
@Observable
final class SparkleUpdateController {
    static let shared = SparkleUpdateController()

    private let updaterController: SPUStandardUpdaterController

    var canCheckForUpdates = false
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    #if DEBUG
    private static let startsUpdater = false
    #else
    private static let startsUpdater = true
    #endif

    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: Self.startsUpdater,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        canCheckObservation = updaterController.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] _, change in
            let canCheck = change.newValue ?? false
            Task { @MainActor in
                self?.canCheckForUpdates = canCheck
            }
        }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
