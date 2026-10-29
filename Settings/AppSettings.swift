import AppKit
import SwiftUI

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
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    @ObservationIgnored private var savePromptsTask: Task<Void, Never>?
    @ObservationIgnored private var saveLanguagesTask: Task<Void, Never>?

    // Edge case: Observation cannot see UserDefaults, so every stored read touches `revision`
    // and every write bumps it. (@AppStorage is no fix: it only publishes binding writes.)
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

    var hotkeyKeyCode: Int {
        get { stored(.hotkeyKeyCode, default: Int(KeyCode.rightCommand)) }
        set { store(newValue, for: .hotkeyKeyCode) }
    }

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

    private var revision = 0

    private func stored<Value>(_ key: UserDefaultsKey, default fallback: Value) -> Value {
        _ = revision
        return defaults.object(forKey: key.rawValue) as? Value ?? fallback
    }

    private func store(_ newValue: some Any, for key: UserDefaultsKey) {
        revision &+= 1
        defaults.set(newValue, forKey: key.rawValue)
    }

    var sttLanguage: STTLanguage {
        get { STTLanguage(rawValue: sttLanguageRaw) ?? .auto }
        set { sttLanguageRaw = newValue.rawValue }
    }

    var appPrompts: [AppPrompt] = [] {
        didSet { saveAppPrompts() }
    }

    var appSTTLanguages: [AppSTTLanguage] = [] {
        didSet { saveAppSTTLanguages() }
    }

    var recordingMode: RecordingMode {
        get { RecordingMode(rawValue: recordingModeRaw) ?? .hold }
        set { recordingModeRaw = newValue.rawValue }
    }

    private init() {
        migrateSupersededUnifiedPrompt()
        loadAppPrompts()
        loadAppSTTLanguages()
    }

    // Edge case: older builds stored the default verbatim. An outdated copy never mentions the
    // OCR block, so the model reproduces the screen text instead of following the command.
    private func migrateSupersededUnifiedPrompt() {
        let stored = unifiedSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stored.isEmpty else { return }
        let isSuperseded = DefaultPrompts.supersededUnified.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == stored
        }
        guard isSuperseded else { return }
        dlog("[Settings] clearing superseded unified prompt, falling back to the current default")
        unifiedSystemPrompt = ""
    }

    // Edge case: clearing (not storing the default) keeps the prompt tracking later improvements.
    func resetUnifiedPrompt() {
        unifiedSystemPrompt = ""
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
           let prompts = try? decoder.decode([AppPrompt].self, from: data)
        {
            appPrompts = prompts
        }
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
           let langs = try? decoder.decode([AppSTTLanguage].self, from: data)
        {
            appSTTLanguages = langs
        }
    }
}
