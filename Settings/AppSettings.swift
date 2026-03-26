import SwiftUI

enum RecordingMode: String, CaseIterable {
    case hold = "hold"
    case toggle = "toggle"

    var displayName: String {
        switch self {
        case .hold: return "Hold-to-talk"
        case .toggle: return "Toggle"
        }
    }
}

enum AppState: Equatable {
    case idle
    case recording
    case transcribing
    case processingLLM
    case done
    case error(String)
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let defaultPrompt = """
    Popraw tekst dyktowany po polsku. Zasady:
    1. Usuń wyrazy-wypełniacze: yyy, eee, hmm, no, więc, tak jakby, w sumie, powiedzmy, że tak powiem
    2. Popraw interpunkcję — dodaj kropki, przecinki, znaki zapytania
    3. Popraw oczywiste literówki i przejęzyczenia
    4. Nie zmieniaj znaczenia ani stylu wypowiedzi
    5. Nie dodawaj niczego od siebie
    6. Zwróć TYLKO poprawiony tekst, bez komentarzy
    """

    @AppStorage("llmPrompt") var llmPrompt: String = AppSettings.defaultPrompt
    @AppStorage("sttModelId") var sttModelId: String = "large-v3-turbo"
    @AppStorage("llmModelId") var llmModelId: String = "mlx-community/Qwen3-4B-Instruct-4bit"
    @AppStorage("recordingMode") var recordingModeRaw: String = RecordingMode.hold.rawValue
    @AppStorage("llmCleanupEnabled") var llmCleanupEnabled: Bool = true
    @AppStorage("hotkeyKeyCode") var hotkeyKeyCode: Int = 49 // Space
    @AppStorage("hotkeyModifiers") var hotkeyModifiers: Int = 524288 // Option

    var recordingMode: RecordingMode {
        get { RecordingMode(rawValue: recordingModeRaw) ?? .hold }
        set { recordingModeRaw = newValue.rawValue }
    }

    @Published var appState: AppState = .idle
    @Published var lastTranscription: String = ""
    @Published var lastCleanedText: String = ""

    private init() {}

    func resetPrompt() {
        llmPrompt = Self.defaultPrompt
    }
}
