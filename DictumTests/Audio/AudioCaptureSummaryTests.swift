@testable import Dictum
import Foundation
import Testing

struct AudioCaptureSummaryTests {
    @Test func `duration follows frames at the capture sample rate`() {
        let summary = AudioCaptureSummary(frames: 24000, sampleRate: 48000)
        #expect(summary.duration == 0.5)
        #expect(AudioCaptureSummary().duration == 0)
    }

    @Test func `signal needs both captured frames and a nonzero peak`() {
        #expect(!AudioCaptureSummary().hasSignal)
        #expect(!AudioCaptureSummary(frames: 1600, peak: 0).hasSignal)
        #expect(!AudioCaptureSummary(frames: 0, peak: 0.4).hasSignal)
        #expect(AudioCaptureSummary(frames: 1600, peak: 0.4).hasSignal)
    }

    @Test func `level lifts quiet peaks and never exceeds one`() {
        #expect(AudioCaptureSummary(recentPeak: 0.25).level == 0.5)
        #expect(AudioCaptureSummary(recentPeak: 4).level == 1)
        #expect(AudioCaptureSummary().level == 0)
    }
}
