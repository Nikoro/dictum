import AVFoundation
import Combine

@MainActor
final class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0

    private var engine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    func startRecording() throws {
        audioBuffer = []
        let engine = AVAudioEngine()
        self.engine = engine

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        // Install tap at hardware format — AVAudioEngine handles conversion
        let desiredSampleRate: Double = 16000
        let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: desiredSampleRate,
            channels: 1,
            interleaved: false
        )!

        // If hardware is different from desired, use a converter
        let converter: AVAudioConverter?
        if hardwareFormat.sampleRate != desiredSampleRate || hardwareFormat.channelCount != 1 {
            converter = AVAudioConverter(from: hardwareFormat, to: desiredFormat)
        } else {
            converter = nil
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self else { return }

            let samplesBuffer: AVAudioPCMBuffer
            if let converter {
                let frameCount = AVAudioFrameCount(
                    Double(buffer.frameLength) * desiredSampleRate / hardwareFormat.sampleRate
                )
                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: desiredFormat,
                    frameCapacity: frameCount
                ) else { return }

                var error: NSError?
                let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                guard status != .error, error == nil else { return }
                samplesBuffer = convertedBuffer
            } else {
                samplesBuffer = buffer
            }

            guard let channelData = samplesBuffer.floatChannelData?[0] else { return }
            let frameLength = Int(samplesBuffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

            // Calculate audio level for UI
            let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(frameLength))

            self.bufferLock.lock()
            self.audioBuffer.append(contentsOf: samples)
            self.bufferLock.unlock()

            DispatchQueue.main.async {
                self.audioLevel = rms
            }
        }

        try engine.start()
        isRecording = true
    }

    func stopRecording() -> [Float] {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        isRecording = false
        audioLevel = 0

        bufferLock.lock()
        let samples = audioBuffer
        audioBuffer = []
        bufferLock.unlock()

        return samples
    }
}
