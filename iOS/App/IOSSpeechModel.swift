import Foundation

enum IOSSpeechModel: String, CaseIterable, Identifiable, Sendable {
    case ultra
    case parakeetV3 = "v3"

    var id: Self {
        self
    }

    var usesUltra: Bool {
        self == .ultra
    }

    var name: String {
        usesUltra ? "Parakeet Ultra" : "Parakeet v3"
    }

    var approximateSize: String {
        usesUltra ? "≈630 MB" : "≈480 MB"
    }
}

struct IOSModelInstallation: Sendable {
    let installed: Bool
    let bytes: Int64?
}
