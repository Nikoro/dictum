import Foundation
import Observation

enum AppState: Equatable, Sendable {
    case idle
    case warmingUp
    case recording
    case transcribing
    case processingLLM
    case error(String)
}

@MainActor
@Observable
final class AppRuntimeState {
    static let shared = AppRuntimeState()

    var appState: AppState = .idle
    var lastTranscription: String = ""
    var lastCleanedText: String = ""

    private init() {}
}
