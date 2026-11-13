import FluidAudio
import Foundation

enum ParakeetVariant: String, CaseIterable, Sendable {
    case version3 = "parakeet-tdt-0.6b-v3"
    case ultra = "parakeet-ultra"
    case redux = "parakeet-redux"

    var version: AsrModelVersion {
        switch self {
        case .version3: .v3
        case .ultra: .ultra
        case .redux: .redux
        }
    }

    var model: SpeechModelInfo {
        let details: (String, Int64, String) = switch self {
        case .version3: ("Parakeet TDT v3", 480_000_000, "stt.parakeet_v3.desc")
        case .ultra: ("Parakeet Ultra", 630_000_000, "stt.parakeet_ultra.desc")
        case .redux: ("Parakeet Redux", 220_000_000, "stt.parakeet_redux.desc")
        }
        return SpeechModelInfo(
            id: rawValue, displayName: details.0, sizeBytes: details.1, descriptionKey: details.2, engine: .parakeet
        )
    }

    var directory: URL {
        AsrModels.defaultCacheDirectory(for: version)
    }

    var isDownloaded: Bool {
        AsrModels.modelsExist(at: directory, version: version)
    }
}
