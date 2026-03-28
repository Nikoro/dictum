import SwiftUI
import AppKit

// MARK: - App Prompt (per-app LLM prompt)

struct AppPrompt: Identifiable, Codable, Equatable {
    var id: String { bundleId }
    let bundleId: String
    var appName: String
    var prompt: String
    var enabled: Bool = true

    /// Resolve the final prompt: if it contains {{text}}, replace placeholder; otherwise use as system prompt.
    func resolve(with text: String) -> (systemPrompt: String?, userMessage: String) {
        if prompt.contains("{{text}}") {
            return (nil, prompt.replacingOccurrences(of: "{{text}}", with: text))
        } else {
            return (prompt, text)
        }
    }
}

enum RecordingMode: String, CaseIterable {
    case hold = "hold"
    case toggle = "toggle"

    var displayName: String {
        switch self {
        case .hold: return String(localized: "mode.hold", defaultValue: "Hold-to-talk")
        case .toggle: return String(localized: "mode.toggle", defaultValue: "Toggle")
        }
    }
}

enum AppState: Equatable {
    case idle
    case warmingUp
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

    @AppStorage("llmPrompt") var llmPrompt: String = ""
    @AppStorage("sttModelId") var sttModelId: String = "openai_whisper-large-v3_turbo"
    @AppStorage("llmModelId") var llmModelId: String = "mlx-community/Qwen3.5-4B-4bit"
    @AppStorage("recordingMode") var recordingModeRaw: String = RecordingMode.hold.rawValue
    @AppStorage("llmCleanupEnabled") var llmCleanupEnabled: Bool = false
    @AppStorage("llmGeneralPromptEnabled") var llmGeneralPromptEnabled: Bool = true
    @AppStorage("hotkeyKeyCode") var hotkeyKeyCode: Int = 54 // Right Command
    @AppStorage("hotkeyModifiers") var hotkeyModifiers: Int = 0 // none (modifier-only)
    @AppStorage("hotkeyIsModifierOnly") var hotkeyIsModifierOnly: Bool = true

    @Published var appPrompts: [AppPrompt] = [] {
        didSet { saveAppPrompts() }
    }

    var recordingMode: RecordingMode {
        get { RecordingMode(rawValue: recordingModeRaw) ?? .hold }
        set { recordingModeRaw = newValue.rawValue }
    }

    @Published var appState: AppState = .idle
    @Published var lastTranscription: String = ""
    @Published var lastCleanedText: String = ""

    private init() {
        loadAppPrompts()
    }

    func resetPrompt() {
        llmPrompt = Self.defaultPrompt
    }

    // MARK: - Per-app prompts

    /// Resolve which prompt to use for a given frontmost app.
    /// Returns nil when no prompt applies (general disabled + no per-app match).
    func resolvePrompt(for bundleId: String?) -> String? {
        if let bundleId,
           let appPrompt = appPrompts.first(where: { $0.bundleId == bundleId && $0.enabled }),
           !appPrompt.prompt.isEmpty {
            return appPrompt.prompt
        }
        return llmGeneralPromptEnabled && !llmPrompt.isEmpty ? llmPrompt : nil
    }

    func addAppPrompt(_ prompt: AppPrompt) {
        guard !appPrompts.contains(where: { $0.bundleId == prompt.bundleId }) else { return }
        appPrompts.append(prompt)
    }

    func removeAppPrompt(bundleId: String) {
        appPrompts.removeAll { $0.bundleId == bundleId }
    }

    func updateAppPrompt(bundleId: String, prompt: String) {
        guard let idx = appPrompts.firstIndex(where: { $0.bundleId == bundleId }) else { return }
        appPrompts[idx].prompt = prompt
    }

    func toggleAppPrompt(bundleId: String) {
        guard let idx = appPrompts.firstIndex(where: { $0.bundleId == bundleId }) else { return }
        appPrompts[idx].enabled.toggle()
    }

    private func saveAppPrompts() {
        if let data = try? JSONEncoder().encode(appPrompts) {
            UserDefaults.standard.set(data, forKey: "appPrompts")
        }
    }

    private func loadAppPrompts() {
        if let data = UserDefaults.standard.data(forKey: "appPrompts"),
           let prompts = try? JSONDecoder().decode([AppPrompt].self, from: data) {
            appPrompts = prompts
        }
    }
}
