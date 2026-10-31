@testable import Dictum
import Testing

@MainActor
struct LiveChunkTranscriberTests {
    @Test
    func `finishing does not wait for the next live-chunk poll`() async throws {
        let silence = [Float](repeating: 0, count: 16000)
        let transcriber = LiveChunkTranscriber(audioSource: StaticAudioSource(samples: silence), language: "pl") { false }
        transcriber.start()
        try await Task.sleep(for: .milliseconds(50))

        let started = ContinuousClock.now
        _ = try await transcriber.finish(allSamples: silence)

        #expect(ContinuousClock.now - started < .milliseconds(200))
    }
}

private final class StaticAudioSource: CapturedAudioSource {
    let samples: [Float]

    init(samples: [Float]) {
        self.samples = samples
    }

    var capturedSampleCount: Int {
        samples.count
    }

    func capturedSamples(in range: Range<Int>) -> [Float] {
        Array(samples[range.clamped(to: 0 ..< samples.count)])
    }
}
