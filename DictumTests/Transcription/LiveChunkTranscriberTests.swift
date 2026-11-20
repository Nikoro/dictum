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

    @Test
    func `live polling survives the recorder clearing its buffer before finish`() async throws {
        let source = StaticAudioSource(samples: [Float](repeating: 0, count: 16000 * 29))
        let transcriber = LiveChunkTranscriber(audioSource: source, language: "pl") { false }
        transcriber.start()
        try await Task.sleep(for: .milliseconds(1300))

        source.samples = []
        try await Task.sleep(for: .milliseconds(1200))

        let text = try await transcriber.finish(allSamples: [])
        #expect(text.isEmpty)
    }
}

private final class StaticAudioSource: CapturedAudioSource {
    var samples: [Float]

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
