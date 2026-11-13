import FluidAudio
import Foundation
import Observation

@Observable
@MainActor
final class ModelPreparation {
    enum Phase { case checking, downloading, compiling, loading }

    private(set) var phase = Phase.loading
    private(set) var fraction: Double?
    private(set) var startedAt: Date?
    private(set) var duration: TimeInterval?
    var storageBytes: Int64?

    func begin() {
        phase = .loading
        fraction = nil
        startedAt = Date()
        duration = nil
        storageBytes = nil
    }

    func update(_ progress: DownloadProgress) {
        guard startedAt != nil else { return }
        switch progress.phase {
        case .listing:
            phase = .checking
            fraction = nil
        case .downloading:
            phase = .downloading
            // Edge case: FluidAudio 0.18 assigns half of each package's progress to compilation.
            // Show its byte progress as a package download, never as total model preparation.
            fraction = min(max(progress.fractionCompleted * 2, 0), 1)
        case .compiling:
            phase = .compiling
            fraction = nil
        }
    }

    func finish() {
        duration = startedAt.map { Date().timeIntervalSince($0) }
        startedAt = nil
        fraction = nil
    }
}
