import SwiftUI
import AppKit

enum UserDefaultsKey: String {
    case llmPrompt
    case unifiedSystemPrompt
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
    case smartContextEnabled
    case contextScreenshot
    case contextSelectedText
    case contextClipboard
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var savePromptsTask: Task<Void, Never>?
    private var saveLanguagesTask: Task<Void, Never>?

    static let defaultPrompt = """
    Popraw tekst dyktowany po polsku. Zasady:
    1. Usuń wyrazy-wypełniacze: yyy, eee, hmm, no, więc, tak jakby, w sumie, powiedzmy, że tak powiem
    2. Popraw interpunkcję — dodaj kropki, przecinki, znaki zapytania
    3. Popraw oczywiste literówki i przejęzyczenia
    4. Nie zmieniaj znaczenia ani stylu wypowiedzi
    5. Nie dodawaj niczego od siebie
    6. Zwróć TYLKO poprawiony tekst, bez komentarzy
    """

    static let defaultUnifiedPrompt = """
    You are a voice input assistant. You receive:
    - A screenshot of the user's active window
    - Extracted text from that screenshot (OCR — use as ground truth for spelling, especially Polish characters and proper names)
    - The app name they're in
    - Any text they have selected
    - Their spoken words (transcribed)

    Your job is to figure out what they want and return ONLY the text to be pasted. No explanations, no markdown, no quotes.

    Rules:
    - If the user is simply dictating text (speaking sentences, notes, thoughts), clean it up: fix punctuation, remove filler words, fix obvious typos. Ignore the screenshot and OCR.
    - If the user is giving a command about what's on screen (e.g. "reply to him that...", "summarize this", "translate this"), use the screenshot, OCR text, and selected text to understand the context, then execute the command.
    - When quoting or referencing on-screen text, prefer the OCR text for exact spelling over what you see in the image.
    - If replying to a conversation, match the language and formality level visible in the screenshot.
    - Always return just the final text. Nothing else.
    """

    // Scalar prefs are stored in UserDefaults behind computed properties rather than
    // @AppStorage: @AppStorage only publishes when written through a SwiftUI binding, so
    // writes from elsewhere in the app (e.g. WhisperModelStore adopting a freshly downloaded
    // model) would never refresh the UI. Codable arrays (appPrompts, appSTTLanguages) use
    // @Published because neither wrapper supports Codable.
    var llmPrompt: String {
        get { stored(.llmPrompt, default: "") }
        set { store(newValue, for: .llmPrompt) }
    }

    var unifiedSystemPrompt: String {
        get { stored(.unifiedSystemPrompt, default: "") }
        set { store(newValue, for: .unifiedSystemPrompt) }
    }

    var sttModelId: String {
        get { stored(.sttModelId, default: "openai_whisper-large-v3_turbo") }
        set { store(newValue, for: .sttModelId) }
    }

    var llmModelId: String {
        get { stored(.llmModelId, default: "mlx-community/gemma-4-e4b-it-4bit") }
        set { store(newValue, for: .llmModelId) }
    }

    var recordingModeRaw: String {
        get { stored(.recordingMode, default: RecordingMode.hold.rawValue) }
        set { store(newValue, for: .recordingMode) }
    }

    var llmCleanupEnabled: Bool {
        get { stored(.llmCleanupEnabled, default: false) }
        set { store(newValue, for: .llmCleanupEnabled) }
    }

    var llmGeneralPromptEnabled: Bool {
        get { stored(.llmGeneralPromptEnabled, default: true) }
        set { store(newValue, for: .llmGeneralPromptEnabled) }
    }

    /// Default 54 = Right Command.
    var hotkeyKeyCode: Int {
        get { stored(.hotkeyKeyCode, default: 54) }
        set { store(newValue, for: .hotkeyKeyCode) }
    }

    /// Default 0 = no modifiers (modifier-only hotkey).
    var hotkeyModifiers: Int {
        get { stored(.hotkeyModifiers, default: 0) }
        set { store(newValue, for: .hotkeyModifiers) }
    }

    var hotkeyIsModifierOnly: Bool {
        get { stored(.hotkeyIsModifierOnly, default: true) }
        set { store(newValue, for: .hotkeyIsModifierOnly) }
    }

    var sttLanguageRaw: String {
        get { stored(.sttLanguage, default: STTLanguage.systemDefault.rawValue) }
        set { store(newValue, for: .sttLanguage) }
    }

    var hasCompletedSetup: Bool {
        get { stored(.hasCompletedSetup, default: false) }
        set { store(newValue, for: .hasCompletedSetup) }
    }

    var smartContextEnabled: Bool {
        get { stored(.smartContextEnabled, default: true) }
        set { store(newValue, for: .smartContextEnabled) }
    }

    var contextScreenshot: Bool {
        get { stored(.contextScreenshot, default: true) }
        set { store(newValue, for: .contextScreenshot) }
    }

    var contextSelectedText: Bool {
        get { stored(.contextSelectedText, default: true) }
        set { store(newValue, for: .contextSelectedText) }
    }

    var contextClipboard: Bool {
        get { stored(.contextClipboard, default: true) }
        set { store(newValue, for: .contextClipboard) }
    }

    private let defaults = UserDefaults.standard

    private func stored<Value>(_ key: UserDefaultsKey, default fallback: Value) -> Value {
        defaults.object(forKey: key.rawValue) as? Value ?? fallback
    }

    private func store<Value>(_ newValue: Value, for key: UserDefaultsKey) {
        objectWillChange.send()
        defaults.set(newValue, forKey: key.rawValue)
    }

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

    /// Earlier wordings of `defaultUnifiedPrompt`. A stored prompt matching one of these was
    /// never written by the user — the settings UI used to persist the default just for being
    /// opened — so it is cleared and the current default takes over. Anything else is a genuine
    /// customization and is left untouched.
    private static let supersededUnifiedPrompts: [String] = [
        """
        You are a voice input assistant. You receive:
        - A screenshot of the user's active window
        - The app name they're in
        - Any text they have selected
        - Their spoken words (transcribed)

        Your job is to figure out what they want and return ONLY the text to be pasted. No explanations, no markdown, no quotes.

        Rules:
        - If the user is simply dictating text (speaking sentences, notes, thoughts), clean it up: fix punctuation, remove filler words, fix obvious typos. Ignore the screenshot.
        - If the user is giving a command about what's on screen (e.g. "reply to him that...", "summarize this", "translate this"), use the screenshot and selected text to understand the context, then execute the command.
        - If replying to a conversation, match the language and formality level visible in the screenshot.
        - Always return just the final text. Nothing else.
        """
    ]

    private init() {
        migrateSupersededUnifiedPrompt()
        loadAppPrompts()
        loadAppSTTLanguages()
    }

    /// A stored copy of an old default describes inputs the pipeline no longer sends — most
    /// visibly it never mentions the OCR block — which leaves the model with a large unexplained
    /// wall of screen text and makes it reproduce that text instead of following the command.
    private func migrateSupersededUnifiedPrompt() {
        let stored = unifiedSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stored.isEmpty else { return }
        let isSuperseded = Self.supersededUnifiedPrompts.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == stored
        }
        guard isSuperseded else { return }
        dlog("[Settings] clearing superseded unified prompt, falling back to the current default")
        unifiedSystemPrompt = ""
    }

    func resetPrompt() {
        llmPrompt = Self.defaultPrompt
    }

    /// Clears the override rather than storing the default, so the prompt keeps tracking
    /// `defaultUnifiedPrompt` as it evolves.
    func resetUnifiedPrompt() {
        unifiedSystemPrompt = ""
    }

    // MARK: - Per-app prompts

    /// Resolve the full system prompt for a given frontmost app.
    /// Base = unified prompt (always applies). Per-app or general prompt layered on top.
    func resolvePrompt(for bundleId: String?) -> String {
        let base = unifiedSystemPrompt.isEmpty ? Self.defaultUnifiedPrompt : unifiedSystemPrompt

        if let bundleId,
           let appPrompt = appPrompts.first(where: { $0.bundleId == bundleId && $0.enabled }),
           !appPrompt.prompt.isEmpty {
            return base + "\n\nAdditional instructions for this app:\n" + appPrompt.prompt
        }

        if llmGeneralPromptEnabled, !llmPrompt.isEmpty {
            return base + "\n\nAdditional instructions:\n" + llmPrompt
        }

        return base
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
        savePromptsTask?.cancel()
        savePromptsTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            if let data = try? encoder.encode(appPrompts) {
                UserDefaults.standard.set(data, forKey: UserDefaultsKey.appPrompts.rawValue)
            }
        }
    }

    private func loadAppPrompts() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKey.appPrompts.rawValue),
           let prompts = try? decoder.decode([AppPrompt].self, from: data) {
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

    /// Resolve the OCR recognition languages for a given frontmost app, following the same
    /// per-app override as `resolveSTTLanguage(for:)`.
    func resolveOCRLanguages(for bundleId: String?) -> [String] {
        if let bundleId,
           let appLang = appSTTLanguages.first(where: { $0.bundleId == bundleId && $0.enabled }) {
            return appLang.language.ocrLanguages
        }
        return sttLanguage.ocrLanguages
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
        saveLanguagesTask?.cancel()
        saveLanguagesTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            if let data = try? encoder.encode(appSTTLanguages) {
                UserDefaults.standard.set(data, forKey: UserDefaultsKey.appSTTLanguages.rawValue)
            }
        }
    }

    private func loadAppSTTLanguages() {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKey.appSTTLanguages.rawValue),
           let langs = try? decoder.decode([AppSTTLanguage].self, from: data) {
            appSTTLanguages = langs
        }
    }
}
