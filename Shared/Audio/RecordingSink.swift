import AVFoundation
import Foundation

final class RecordingSink: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var failure: Error?
    private var capture = AudioCaptureSummary()

    func begin(url: URL, format: AVAudioFormat) throws {
        lock.lock()
        defer { lock.unlock() }
        failure = nil
        capture = AudioCaptureSummary(sampleRate: format.sampleRate)
        file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let file, failure == nil, capture.duration < 180 else { return }
        do {
            try file.write(from: buffer)
            capture.frames += Int64(buffer.frameLength)
            capture.recentPeak = Self.peak(in: buffer)
            capture.peak = max(capture.peak, capture.recentPeak)
        } catch {
            failure = error
        }
    }

    var framesWritten: AVAudioFramePosition {
        lock.lock()
        defer { lock.unlock() }
        return capture.frames
    }

    var summary: AudioCaptureSummary {
        lock.lock()
        defer { lock.unlock() }
        return capture
    }

    private static func peak(in buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData else { return 0 }
        var peak: Float = 0
        for channel in 0 ..< Int(buffer.format.channelCount) {
            for frame in 0 ..< Int(buffer.frameLength) {
                peak = max(peak, abs(channels[channel][frame]))
            }
        }
        return peak
    }

    func finish() throws {
        lock.lock()
        defer { lock.unlock() }
        file?.close()
        file = nil
        if let failure {
            throw failure
        }
    }
}
