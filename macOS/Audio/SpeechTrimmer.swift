import Accelerate

enum SpeechTrimmer {
    private static let sampleRate = 16000
    static let frameLength = 480
    private static let minimumSpeechSeconds = 0.25
    private static let leadingContextSeconds = 0.25
    private static let trailingContextSeconds = 0.35
    private static let silencePaddingSeconds = 0.3
    private static let absoluteFloorDecibels: Float = -55
    private static let speechAboveNoiseDecibels: Float = 10

    // Edge case: Whisper hallucinates text ("Dziękuję.", subtitles credits) on long silent tails
    // and on speechless recordings, so silence is cut and speechless audio is dropped entirely.
    static func speechOnly(_ samples: [Float]) -> [Float]? {
        let levels = frameLevels(samples)
        let threshold = speechThreshold(levels)
        guard let first = levels.firstIndex(where: { $0 > threshold }),
              let last = levels.lastIndex(where: { $0 > threshold }),
              hasEnoughSpeech(levels, threshold: threshold)
        else {
            return nil
        }
        let start = max(0, first * frameLength - samplesFor(leadingContextSeconds))
        let end = min(samples.count, (last + 1) * frameLength + samplesFor(trailingContextSeconds))
        let padding = [Float](repeating: 0, count: samplesFor(silencePaddingSeconds))
        return padding + samples[start ..< end] + padding
    }

    static func frameLevels(_ samples: [Float]) -> [Float] {
        stride(from: 0, to: samples.count - frameLength + 1, by: frameLength).map { start in
            let meanSquare = vDSP.meanSquare(samples[start ..< start + frameLength])
            return 10 * log10(max(meanSquare, 1e-10))
        }
    }

    static func speechThreshold(_ levels: [Float]) -> Float {
        let sorted = levels.sorted()
        let noiseFloor = sorted.isEmpty ? absoluteFloorDecibels : sorted[sorted.count / 10]
        return max(noiseFloor + speechAboveNoiseDecibels, absoluteFloorDecibels)
    }

    private static func hasEnoughSpeech(_ levels: [Float], threshold: Float) -> Bool {
        let speechFrames = levels.count { $0 > threshold }
        return Double(speechFrames * frameLength) / Double(sampleRate) >= minimumSpeechSeconds
    }

    private static func samplesFor(_ seconds: Double) -> Int {
        Int(seconds * Double(sampleRate))
    }
}
