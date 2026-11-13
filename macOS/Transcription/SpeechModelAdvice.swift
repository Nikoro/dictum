import Foundation

enum SpeechModelRecommendation {
    case accuracy
    case speed
    case compact

    var title: String {
        switch self {
        case .accuracy: String(localized: "stt.recommendation.accuracy", defaultValue: "Recommended: accuracy")
        case .speed: String(localized: "stt.recommendation.speed", defaultValue: "Recommended: speed")
        case .compact: String(localized: "stt.recommendation.compact", defaultValue: "Smaller download")
        }
    }
}

extension SpeechModelInfo {
    var recommendation: SpeechModelRecommendation? {
        switch id {
        case "openai_whisper-large-v3_turbo": .accuracy
        case "parakeet-ultra": .speed
        case "parakeet-redux": .compact
        default: nil
        }
    }

    var isRecommended: Bool {
        recommendation == .accuracy || recommendation == .speed
    }

    var benchmarkNote: String {
        switch id {
        case "openai_whisper-large-v3_turbo":
            String(localized: "stt.benchmark.whisper_turbo", defaultValue: "3.49% word errors · 3.29 s median inference")
        case "parakeet-ultra":
            String(localized: "stt.benchmark.ultra", defaultValue: "5.64% word errors · 0.082 s median inference")
        case "parakeet-tdt-0.6b-v3":
            String(localized: "stt.benchmark.v3", defaultValue: "6.15% word errors · 0.080 s median inference")
        case "parakeet-redux":
            String(localized: "stt.benchmark.redux", defaultValue: "8.00% word errors · 0.159 s median inference")
        default:
            String(localized: "stt.benchmark.unmeasured", defaultValue: "Not included in this Polish/M4 benchmark.")
        }
    }
}
