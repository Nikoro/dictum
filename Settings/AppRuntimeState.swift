import Foundation

enum AppState: Equatable, Sendable {
    case idle
    case warmingUp
    case recording
    case transcribing
    case processingLLM
    case error(String)
}

@MainActor
final class AppRuntimeState: ObservableObject {
    static let shared = AppRuntimeState()

    @Published var appState: AppState = .idle
    @Published var lastTranscription: String = ""
    @Published var lastCleanedText: String = ""

    private init() {}
}
