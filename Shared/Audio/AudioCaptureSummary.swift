import Foundation

struct AudioCaptureSummary: Equatable, Sendable {
    var frames: Int64 = 0
    var sampleRate: Double = 16000
    var peak: Float = 0
    var recentPeak: Float = 0

    var duration: Double {
        Double(frames) / sampleRate
    }

    var hasSignal: Bool {
        frames > 0 && peak > 0
    }

    var level: Double {
        min(1, sqrt(Double(recentPeak)))
    }
}
