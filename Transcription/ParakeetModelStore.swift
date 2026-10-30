import Observation

@Observable
@MainActor
final class ParakeetModelStore {
    static let shared = ParakeetModelStore()

    private(set) var isDownloaded = ParakeetEngine.isModelDownloaded
    private(set) var isDownloading = false
    var downloadError: String?

    private init() {}

    func download() {
        guard !isDownloading else { return }
        isDownloading = true
        downloadError = nil
        Task {
            do {
                try await ParakeetEngine.shared.loadModel()
                isDownloaded = true
            } catch {
                dlog("[Parakeet] download failed: \(error)")
                downloadError = error.localizedDescription
            }
            isDownloading = false
        }
    }
}
