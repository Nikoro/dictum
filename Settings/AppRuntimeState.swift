import Foundation

enum AppState: Equatable {
    case idle
    case warmingUp
    case recording
    case transcribing
    case processingLLM
    case done
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
