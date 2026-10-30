import Accelerate

// Edge case: AVFAudio tap and converter callbacks are @Sendable yet hand back non-Sendable
// buffers; @preconcurrency keeps that unavoidable crossing a warning.
@preconcurrency import AVFoundation

// Edge case: @unchecked Sendable holds because `engine`, `configurationObserver`,
// `isRecording` and `audioLevel` are only touched on the main actor, and `audioBuffer` only
// under `bufferLock`.
final class AudioRecorder: CapturedAudioSource, @unchecked Sendable {
    var isRecording = false
    var audioLevel: Float = 0

    // Edge case: only reached when a key-up event is lost; without it the buffer grows unbounded.
    static let maxRecordingSeconds = 300

    private var engine: AVAudioEngine?
    private var engineDeviceUID: String?
    private var configurationObserver: (any NSObjectProtocol)?
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private let expectedRecordingSeconds = 60
    private let targetSampleRate = 16000
    private var maxSamples: Int {
        targetSampleRate * Self.maxRecordingSeconds
    }

    @MainActor
    func startRecording(inputDeviceUID: String) throws {
        bufferLock.withLock {
            audioBuffer = []
            audioBuffer.reserveCapacity(targetSampleRate * expectedRecordingSeconds)
        }
        let engine = reusableEngine(for: inputDeviceUID)

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        dlog("[Audio] hardware format: \(hardwareFormat.sampleRate)Hz, \(hardwareFormat.channelCount)ch")

        let audioProcessing = makeAudioProcessingContext(hardwareFormat: hardwareFormat)
        installInputTap(on: inputNode, hardwareFormat: hardwareFormat, context: audioProcessing)
        observeConfigurationChanges(of: engine)

        try engine.start()
        isRecording = true
        dlog("[Audio] engine started")
    }

    // Edge case: the engine is kept between recordings so the next one starts faster; a stopped
    // engine does not hold the microphone, so the privacy indicator stays off while idle.
    @MainActor
    private func reusableEngine(for inputDeviceUID: String) -> AVAudioEngine {
        if let engine, engineDeviceUID == inputDeviceUID, engine.inputNode.outputFormat(forBus: 0).sampleRate > 0 {
            return engine
        }
        let engine = AVAudioEngine()
        if !inputDeviceUID.isEmpty {
            AudioInputDevices.select(inputDeviceUID, on: engine)
        }
        self.engine = engine
        engineDeviceUID = inputDeviceUID
        return engine
    }

    // Edge case: Bluetooth headsets switch from A2DP to HFP when their microphone opens. The
    // format change stops AVAudioEngine, and without a restart the recording stays empty.
    @MainActor
    private func observeConfigurationChanges(of engine: AVAudioEngine) {
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.restartAfterConfigurationChange()
            }
        }
    }

    @MainActor
    private func restartAfterConfigurationChange() {
        guard let engine, isRecording else { return }

        let inputNode = engine.inputNode
        inputNode.removeTap(onBus: 0)
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        dlog("[Audio] configuration changed, new format: \(hardwareFormat.sampleRate)Hz, \(hardwareFormat.channelCount)ch")
        // Edge case: a device mid-switch briefly reports an empty format; another change follows.
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else { return }

        let audioProcessing = makeAudioProcessingContext(hardwareFormat: hardwareFormat)
        installInputTap(on: inputNode, hardwareFormat: hardwareFormat, context: audioProcessing)
        do {
            try engine.start()
            dlog("[Audio] engine restarted")
        } catch {
            dlog("[Audio] engine restart failed: \(error)")
        }
    }

    var capturedSampleCount: Int {
        bufferLock.withLock { audioBuffer.count }
    }

    func capturedSamples(in range: Range<Int>) -> [Float] {
        bufferLock.withLock { Array(audioBuffer[range.clamped(to: 0 ..< audioBuffer.count)]) }
    }

    @MainActor
    func stopRecording() -> [Float] {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        isRecording = false
        audioLevel = 0

        let samples = bufferLock.withLock {
            defer { audioBuffer = [] }
            return audioBuffer
        }

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
        )
        else {
            fatalError("internal: failed to create 16kHz mono Float32 format")
        }

        let converter: AVAudioConverter? = if hardwareFormat.sampleRate != desiredSampleRate || hardwareFormat.channelCount != 1 {
            AVAudioConverter(from: hardwareFormat, to: desiredFormat)
        } else {
            nil
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
                  let samplesBuffer = convertBuffer(buffer, hardwareFormat: hardwareFormat, context: context),
                  let channelData = samplesBuffer.floatChannelData?[0]
            else {
                return
            }

            let frameLength = Int(samplesBuffer.frameLength)
            let samples = UnsafeBufferPointer(start: channelData, count: frameLength)
            appendSamples(samples)
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
        )
        else {
            return nil
        }

        // Edge case: the converter keeps calling this block until its output is full; handing
        // back the same buffer twice would duplicate audio. The block runs synchronously inside
        // `convert`, so the flag is never shared across threads.
        nonisolated(unsafe) var consumed = false
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, error == nil, convertedBuffer.frameLength > 0 else {
            return nil
        }

        return convertedBuffer
    }

    private func appendSamples(_ samples: UnsafeBufferPointer<Float>) {
        guard let baseAddress = samples.baseAddress, !samples.isEmpty else { return }
        var sumOfSquares: Float = 0
        vDSP_svesq(baseAddress, 1, &sumOfSquares, vDSP_Length(samples.count))
        let rms = sqrt(sumOfSquares / Float(samples.count))

        bufferLock.lock()
        let remaining = maxSamples - audioBuffer.count
        if remaining > 0 {
            audioBuffer.append(contentsOf: samples.prefix(remaining))
        }
        bufferLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            audioLevel = rms
        }
    }
}

private struct AudioProcessingContext {
    let desiredSampleRate: Double
    let desiredFormat: AVAudioFormat
    let converter: AVAudioConverter?
}
