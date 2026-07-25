import Foundation

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
        case .auto: return String(localized: "language.auto", defaultValue: "Automatic")
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

    /// BCP-47 tags for Vision text recognition, most likely first. English is always kept as a
    /// fallback because window chrome is usually English no matter what the user dictates.
    var ocrLanguages: [String] {
        guard self != .auto else {
            let system = Self.systemDefault
            return system == .auto ? ["en-US"] : system.ocrLanguages
        }
        guard let tag = Self.ocrTags[self], tag != "en-US" else { return ["en-US"] }
        return [tag, "en-US"]
    }

    private static let ocrTags: [STTLanguage: String] = [
        .pl: "pl-PL", .en: "en-US", .de: "de-DE", .fr: "fr-FR", .es: "es-ES",
        .it: "it-IT", .pt: "pt-BR", .uk: "uk-UA", .cs: "cs-CZ", .nl: "nl-NL",
        .ja: "ja-JP", .ko: "ko-KR", .zh: "zh-Hans", .ru: "ru-RU", .sv: "sv-SE",
        .tr: "tr-TR"
    ]

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

    var displayName: String { appName.replacingOccurrences(of: ".app", with: "") }
}

// MARK: - App Prompt (per-app LLM prompt)

struct AppPrompt: Identifiable, Codable, Equatable {
    var id: String { bundleId }
    let bundleId: String
    var appName: String
    var prompt: String
    var enabled: Bool = true

    var displayName: String { appName.replacingOccurrences(of: ".app", with: "") }
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
