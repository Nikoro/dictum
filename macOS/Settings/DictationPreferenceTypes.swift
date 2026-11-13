import Foundation

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
        case .auto: String(localized: "language.auto", defaultValue: "Automatic")
        case .pl: "Polski"
        case .en: "English"
        case .de: "Deutsch"
        case .fr: "Français"
        case .es: "Español"
        case .it: "Italiano"
        case .pt: "Português"
        case .uk: "Українська"
        case .cs: "Čeština"
        case .nl: "Nederlands"
        case .ja: "日本語"
        case .ko: "한국어"
        case .zh: "中文"
        case .ru: "Русский"
        case .sv: "Svenska"
        case .tr: "Türkçe"
        }
    }

    var whisperCodeOrNilForAutoDetect: String? {
        self == .auto ? nil : rawValue
    }

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

    static var systemDefault: STTLanguage {
        guard let code = Locale.current.language.languageCode?.identifier else { return .auto }
        return STTLanguage(rawValue: code) ?? .auto
    }
}

struct AppSTTLanguage: Identifiable, Codable, Equatable {
    var id: String {
        bundleId
    }

    let bundleId: String
    var appName: String
    var language: STTLanguage
    var enabled: Bool = true

    var displayName: String {
        appName.replacingOccurrences(of: ".app", with: "")
    }
}

struct AppPrompt: Identifiable, Codable, Equatable {
    var id: String {
        bundleId
    }

    let bundleId: String
    var appName: String
    var prompt: String
    var enabled: Bool = true

    var displayName: String {
        appName.replacingOccurrences(of: ".app", with: "")
    }
}

enum RecordingMode: String, CaseIterable, Sendable {
    case hold
    case toggle

    var displayName: String {
        switch self {
        case .hold: String(localized: "mode.hold", defaultValue: "Hold-to-talk")
        case .toggle: String(localized: "mode.toggle", defaultValue: "Toggle")
        }
    }
}

enum SpeechEngine: String, CaseIterable, Sendable {
    case whisper
    case parakeet
}
