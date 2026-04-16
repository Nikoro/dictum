import Accelerate
import AVFoundation
import Combine

final class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0

    private var engine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private let expectedRecordingSeconds = 60
    private let targetSampleRate = 16000

    @MainActor
    func startRecording() throws {
        audioBuffer = []
        audioBuffer.reserveCapacity(targetSampleRate * expectedRecordingSeconds)
        let engine = AVAudioEngine()
        self.engine = engine

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        dlog("[Audio] hardware format: \(hardwareFormat.sampleRate)Hz, \(hardwareFormat.channelCount)ch")

        let audioProcessing = makeAudioProcessingContext(hardwareFormat: hardwareFormat)
        installInputTap(on: inputNode, hardwareFormat: hardwareFormat, context: audioProcessing)

        try engine.start()
        isRecording = true
        dlog("[Audio] engine started")
    }

    @MainActor
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

        dlog("[Audio] stopped, \(samples.count) samples captured")
        return samples
    }

    private func makeAudioProcessingContext(hardwareFormat: AVAudioFormat) -> AudioProcessingContext {
        let desiredSampleRate = Double(targetSampleRate)
        guard let desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: desiredSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            fatalError("internal: failed to create 16kHz mono Float32 format")
        }

        let converter: AVAudioConverter?
        if hardwareFormat.sampleRate != desiredSampleRate || hardwareFormat.channelCount != 1 {
            converter = AVAudioConverter(from: hardwareFormat, to: desiredFormat)
        } else {
            converter = nil
        }

        return AudioProcessingContext(
            desiredSampleRate: desiredSampleRate,
            desiredFormat: desiredFormat,
            converter: converter
        )
    }

    private func installInputTap(
        on inputNode: AVAudioInputNode,
        hardwareFormat: AVAudioFormat,
        context: AudioProcessingContext
    ) {
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self,
                  let samplesBuffer = self.convertBuffer(buffer, hardwareFormat: hardwareFormat, context: context),
                  let channelData = samplesBuffer.floatChannelData?[0] else {
                return
            }

            let frameLength = Int(samplesBuffer.frameLength)
            let samples = UnsafeBufferPointer(start: channelData, count: frameLength)
            self.appendSamples(samples)
        }
    }

    private func convertBuffer(
        _ buffer: AVAudioPCMBuffer,
        hardwareFormat: AVAudioFormat,
        context: AudioProcessingContext
    ) -> AVAudioPCMBuffer? {
        guard let converter = context.converter else {
            return buffer
        }

        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * context.desiredSampleRate / hardwareFormat.sampleRate
        )
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: context.desiredFormat,
            frameCapacity: frameCount
        ) else {
            return nil
        }

        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, error == nil else {
            return nil
        }

        return convertedBuffer
    }

    private func appendSamples(_ samples: UnsafeBufferPointer<Float>) {
        guard let baseAddress = samples.baseAddress, samples.count > 0 else { return }
        var sumOfSquares: Float = 0
        vDSP_svesq(baseAddress, 1, &sumOfSquares, vDSP_Length(samples.count))
        let rms = sqrt(sumOfSquares / Float(samples.count))

        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)
        bufferLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.objectWillChange.send()
            self.audioLevel = rms
        }
    }
}

private struct AudioProcessingContext {
    let desiredSampleRate: Double
    let desiredFormat: AVAudioFormat
    let converter: AVAudioConverter?
}
