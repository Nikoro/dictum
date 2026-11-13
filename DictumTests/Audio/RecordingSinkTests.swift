import AVFoundation
@testable import Dictum
import Foundation
import Testing

struct RecordingSinkTests {
    @Test func `recording diagnostics distinguish digital silence from captured audio and reset for the next message`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 160))
        buffer.frameLength = 160
        let channel = try #require(buffer.floatChannelData?[0])
        let sink = RecordingSink()
        try sink.begin(url: directory.appendingPathComponent("first.caf"), format: format)
        channel.update(repeating: 0, count: 160)
        sink.write(buffer)
        #expect(!sink.summary.hasSignal)
        channel.update(repeating: 0.25, count: 160)
        sink.write(buffer)
        try sink.finish()
        #expect(sink.summary.hasSignal)
        #expect(sink.summary.frames == 320)
        #expect(sink.summary.duration == 0.02)
        #expect(sink.summary.level == 0.5)
        try sink.begin(url: directory.appendingPathComponent("second.caf"), format: format)
        #expect(!sink.summary.hasSignal)
        #expect(sink.summary.frames == 0)
        try sink.finish()
    }
}
