import AVFoundation
@testable import Dictum
import Foundation
import Testing

struct AudioRecordingTapTests {
    @MainActor @Test
    func `a tap installed on the main actor records on the audio queue without an executor assertion`() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: file) }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        let sink = RecordingSink()
        try sink.begin(url: file, format: format)
        AudioRecordingTap.install(on: engine.mainMixerNode, format: format, sink: sink)
        defer {
            engine.stop()
            engine.mainMixerNode.removeTap(onBus: 0)
        }
        try player.scheduleBuffer(silence(format: format), completionHandler: nil)
        try engine.start()
        player.play()
        try await waitForSamples(in: sink)
        engine.stop()
        try sink.finish()
        let recording = try AVAudioFile(forReading: file)
        #expect(recording.length > 0)
    }

    private func silence(format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000))
        buffer.frameLength = buffer.frameCapacity
        let channels = try #require(buffer.floatChannelData)
        for index in 0 ..< Int(format.channelCount) {
            channels[index].update(repeating: 0, count: Int(buffer.frameLength))
        }
        return buffer
    }

    private func waitForSamples(in sink: RecordingSink) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while sink.framesWritten == 0, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
