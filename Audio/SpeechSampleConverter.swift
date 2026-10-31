@preconcurrency import AVFoundation

// Edge case: one AVAudioConverter per recording keeps its filter state between chunks, so chunk
// borders do not click; it is not thread-safe and is only used on the recorder's drain queue.
final class SpeechSampleConverter {
    static let outputSampleRate: Double = 16000

    private let inputFormat: AVAudioFormat
    private let outputFormat: AVAudioFormat
    private let converter: AVAudioConverter?

    init(inputSampleRate: Double) throws {
        guard let inputFormat = Self.monoFormat(sampleRate: inputSampleRate),
              let outputFormat = Self.monoFormat(sampleRate: Self.outputSampleRate)
        else {
            throw HALInputError(step: "create conversion formats", status: kAudioUnitErr_FormatNotSupported)
        }
        self.inputFormat = inputFormat
        self.outputFormat = outputFormat
        converter = inputSampleRate == Self.outputSampleRate ? nil : AVAudioConverter(from: inputFormat, to: outputFormat)
    }

    func convert(_ samples: [Float]) -> [Float] {
        guard let converter else { return samples }
        guard !samples.isEmpty, let input = makeBuffer(samples) else { return [] }
        return run(converter, feeding: input, endOfStream: false)
    }

    func flush() -> [Float] {
        guard let converter else { return [] }
        return run(converter, feeding: nil, endOfStream: true)
    }

    private func run(_ converter: AVAudioConverter, feeding input: AVAudioPCMBuffer?, endOfStream: Bool) -> [Float] {
        let inputFrames = Double(input?.frameLength ?? 0)
        let capacity = AVAudioFrameCount(inputFrames * outputFormat.sampleRate / inputFormat.sampleRate) + 512
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return [] }
        // Edge case: the block runs synchronously inside `convert`, so the flag is never shared
        // across threads; handing the same buffer back twice would duplicate audio.
        nonisolated(unsafe) var pending = input
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if let buffer = pending {
                pending = nil
                status.pointee = .haveData
                return buffer
            }
            status.pointee = endOfStream ? .endOfStream : .noDataNow
            return nil
        }
        guard error == nil, let channel = output.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else {
            return nil
        }
        samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            channel.update(from: base, count: samples.count)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        return buffer
    }

    private static func monoFormat(sampleRate: Double) -> AVAudioFormat? {
        AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)
    }
}
