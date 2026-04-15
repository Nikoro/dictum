import SwiftUI
import AppKit

// MARK: - STT Language

enum STTLanguage: String, CaseIterable, Codable, Sendable {
    case auto
    case pl
    case en
    case de
    case fr
    case es
    case it
    case pt
    case uk
    case cs
    case nl
    case ja
    case ko
    case zh
    case ru
    case sv
    case tr

    var displayName: String {
        switch self {
        case .auto: return String(localized: "language.auto", defaultValue: "Automatycznie")
        case .pl: return "Polski"
        case .en: return "English"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .es: return "Español"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .uk: return "Українська"
        case .cs: return "Čeština"
        case .nl: return "Nederlands"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .zh: return "中文"
        case .ru: return "Русский"
        case .sv: return "Svenska"
        case .tr: return "Türkçe"
        }
    }

    /// Returns the Whisper language code, or nil for auto-detect.
    var whisperCode: String? {
        self == .auto ? nil : rawValue
    }

    /// Maps the system language to a supported STTLanguage, falling back to .auto.
    static var systemDefault: STTLanguage {
        guard let code = Locale.current.language.languageCode?.identifier else { return .auto }
        return STTLanguage(rawValue: code) ?? .auto
    }
}

// MARK: - Per-app STT language

struct AppSTTLanguage: Identifiable, Codable, Equatable {
    var id: String { bundleId }
    let bundleId: String
    var appName: String
    var language: STTLanguage
    var enabled: Bool = true
}

// MARK: - App Prompt (per-app LLM prompt)

struct AppPrompt: Identifiable, Codable, Equatable {
    var id: String { bundleId }
    let bundleId: String
    var appName: String
    var prompt: String
    var enabled: Bool = true

}

enum RecordingMode: String, CaseIterable, Sendable {
    case hold
    case toggle

    var displayName: String {
        switch self {
        case .hold: return String(localized: "mode.hold", defaultValue: "Hold-to-talk")
        case .toggle: return String(localized: "mode.toggle", defaultValue: "Toggle")
        }
    }
}

enum UserDefaultsKey: String {
    case llmPrompt
    case sttModelId
    case llmModelId
    case recordingMode
    case llmCleanupEnabled
    case llmGeneralPromptEnabled
    case hotkeyKeyCode
    case hotkeyModifiers
    case hotkeyIsModifierOnly
    case sttLanguage
    case hasCompletedSetup
    case appPrompts
    case appSTTLanguages
    case whisperDownloadedModelIds
    case llmDownloadedModelId
}

@MainActor
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

    @AppStorage(UserDefaultsKey.llmPrompt.rawValue) var llmPrompt: String = ""
    @AppStorage(UserDefaultsKey.sttModelId.rawValue) var sttModelId: String = "openai_whisper-large-v3_turbo"
    @AppStorage(UserDefaultsKey.llmModelId.rawValue) var llmModelId: String = "mlx-community/gemma-4-e2b-it-4bit"
    @AppStorage(UserDefaultsKey.recordingMode.rawValue) var recordingModeRaw: String = RecordingMode.hold.rawValue
    @AppStorage(UserDefaultsKey.llmCleanupEnabled.rawValue) var llmCleanupEnabled: Bool = false
    @AppStorage(UserDefaultsKey.llmGeneralPromptEnabled.rawValue) var llmGeneralPromptEnabled: Bool = true
    @AppStorage(UserDefaultsKey.hotkeyKeyCode.rawValue) var hotkeyKeyCode: Int = 54 // Right Command
    @AppStorage(UserDefaultsKey.hotkeyModifiers.rawValue) var hotkeyModifiers: Int = 0 // none (modifier-only)
    @AppStorage(UserDefaultsKey.hotkeyIsModifierOnly.rawValue) var hotkeyIsModifierOnly: Bool = true
    @AppStorage(UserDefaultsKey.sttLanguage.rawValue) var sttLanguageRaw: String = STTLanguage.systemDefault.rawValue
    @AppStorage(UserDefaultsKey.hasCompletedSetup.rawValue) var hasCompletedSetup: Bool = false

    var sttLanguage: STTLanguage {
        get { STTLanguage(rawValue: sttLanguageRaw) ?? .auto }
        set { sttLanguageRaw = newValue.rawValue }
    }

    @Published var appPrompts: [AppPrompt] = [] {
        didSet { saveAppPrompts() }
    }

    @Published var appSTTLanguages: [AppSTTLanguage] = [] {
        didSet { saveAppSTTLanguages() }
    }

    var recordingMode: RecordingMode {
        get { RecordingMode(rawValue: recordingModeRaw) ?? .hold }
        set { recordingModeRaw = newValue.rawValue }
    }

    private init() {
        loadAppPrompts()
        loadAppSTTLanguages()
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
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.appPrompts.rawValue)
        }
    }

    private func loadAppPrompts() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKey.appPrompts.rawValue),
           let prompts = try? JSONDecoder().decode([AppPrompt].self, from: data) {
            appPrompts = prompts
        }
    }

    // MARK: - Per-app STT language

    /// Resolve which STT language to use for a given frontmost app.
    /// Returns the Whisper language code (e.g. "pl") or nil for auto-detect.
    func resolveSTTLanguage(for bundleId: String?) -> String? {
        if let bundleId,
           let appLang = appSTTLanguages.first(where: { $0.bundleId == bundleId && $0.enabled }) {
            return appLang.language.whisperCode
        }
        return sttLanguage.whisperCode
    }

    func addAppSTTLanguage(_ lang: AppSTTLanguage) {
        guard !appSTTLanguages.contains(where: { $0.bundleId == lang.bundleId }) else { return }
        appSTTLanguages.append(lang)
    }

    func removeAppSTTLanguage(bundleId: String) {
        appSTTLanguages.removeAll { $0.bundleId == bundleId }
    }

    func updateAppSTTLanguage(bundleId: String, language: STTLanguage) {
        guard let idx = appSTTLanguages.firstIndex(where: { $0.bundleId == bundleId }) else { return }
        appSTTLanguages[idx].language = language
    }

    func toggleAppSTTLanguage(bundleId: String) {
        guard let idx = appSTTLanguages.firstIndex(where: { $0.bundleId == bundleId }) else { return }
        appSTTLanguages[idx].enabled.toggle()
    }

    private func saveAppSTTLanguages() {
        if let data = try? JSONEncoder().encode(appSTTLanguages) {
            UserDefaults.standard.set(data, forKey: UserDefaultsKey.appSTTLanguages.rawValue)
        }
    }

    private func loadAppSTTLanguages() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKey.appSTTLanguages.rawValue),
           let langs = try? JSONDecoder().decode([AppSTTLanguage].self, from: data) {
            appSTTLanguages = langs
        }
    }
}
