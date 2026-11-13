import Accelerate
import CoreAudio
import Foundation

// Edge case: @unchecked Sendable holds because capture setup, `isRecording` and `audioLevel` are
// only touched on the main actor, conversion only on `drainQueue`, and `audioBuffer` only under
// `bufferLock`.
final class AudioRecorder: CapturedAudioSource, @unchecked Sendable {
    var isRecording = false
    var audioLevel: Float = 0

    // Edge case: only reached when a key-up event is lost; without it the buffer grows unbounded.
    static let maxRecordingSeconds = 300

    private let capture = HALInputCapture()
    private let drainQueue = DispatchQueue(label: "com.dominikkrajcer.dictum.audio-drain", qos: .userInitiated)
    private var drainTimer: DispatchSourceTimer?
    private var converter: SpeechSampleConverter?
    private var awaitingFirstBufferSince: ContinuousClock.Instant?
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private var selectedUID = ""
    private var hardwareListener: AudioObjectPropertyListenerBlock?
    private let expectedRecordingSeconds = 60
    private var maxSamples: Int {
        Int(SpeechSampleConverter.outputSampleRate) * Self.maxRecordingSeconds
    }

    // Edge case: preparing binds and initializes the input unit without starting it, so the
    // microphone stays off (no privacy indicator) yet the next start skips device setup.
    @MainActor
    func prepare(inputDeviceUID: String) {
        selectedUID = inputDeviceUID
        observeHardwareChanges()
        guard !isRecording, let deviceID = AudioInputDevices.resolve(selectedUID: inputDeviceUID) else { return }
        do {
            try capture.prepare(deviceID: deviceID)
        } catch {
            dlog("[Audio] preparing \(AudioInputDevices.name(of: deviceID)) failed: \(error)")
        }
    }

    @MainActor
    func startRecording(inputDeviceUID: String) throws {
        let requestedAt = ContinuousClock.now
        selectedUID = inputDeviceUID
        observeHardwareChanges()
        bufferLock.withLock {
            audioBuffer = []
            audioBuffer.reserveCapacity(Int(SpeechSampleConverter.outputSampleRate) * expectedRecordingSeconds)
        }
        try startCapture(requestedAt: requestedAt)
        isRecording = true
        startDrainTimer()
        let setupTime = ContinuousClock.now - requestedAt
        let deviceName = AudioInputDevices.name(of: capture.boundDeviceID)
        dlog("[Audio] recording from \(deviceName) at \(capture.sampleRate) Hz, started in \(setupTime)")
    }

    @MainActor
    func stopRecording() -> [Float] {
        capture.stop()
        drainTimer?.cancel()
        drainTimer = nil
        drainQueue.sync { finishConversion() }
        isRecording = false
        audioLevel = 0
        if capture.droppedRenderCycleCount > 0 {
            dlog("[Audio] dropped \(capture.droppedRenderCycleCount) render cycles")
        }

        let samples = bufferLock.withLock {
            defer { audioBuffer = [] }
            return audioBuffer
        }
        dlog("[Audio] stopped, \(samples.count) samples captured")
        prepare(inputDeviceUID: selectedUID)
        return samples
    }

    var capturedSampleCount: Int {
        bufferLock.withLock { audioBuffer.count }
    }

    func capturedSamples(in range: Range<Int>) -> [Float] {
        bufferLock.withLock { Array(audioBuffer[range.clamped(to: 0 ..< audioBuffer.count)]) }
    }

    @MainActor
    private func startCapture(requestedAt: ContinuousClock.Instant) throws {
        guard let deviceID = AudioInputDevices.resolve(selectedUID: selectedUID) else {
            throw HALInputError(step: "find an input device", status: kAudioHardwareBadDeviceError)
        }
        try capture.prepare(deviceID: deviceID)
        let converter = try SpeechSampleConverter(inputSampleRate: capture.sampleRate)
        drainQueue.sync {
            self.converter = converter
            awaitingFirstBufferSince = requestedAt
        }
        try capture.start()
    }

    // Edge case: a device that disappears or changes its sample rate mid-recording (a Bluetooth
    // headset switching profiles) leaves the bound unit silent; the capture is rebuilt on the
    // current device and the samples recorded so far are kept.
    @MainActor
    private func handleHardwareChange() {
        guard isRecording else {
            prepare(inputDeviceUID: selectedUID)
            return
        }
        guard let deviceID = AudioInputDevices.resolve(selectedUID: selectedUID),
              !capture.isPrepared(for: deviceID)
        else {
            return
        }
        capture.stop()
        drainQueue.sync { finishConversion() }
        do {
            try startCapture(requestedAt: .now)
            dlog("[Audio] input changed, continuing on \(AudioInputDevices.name(of: deviceID)) at \(capture.sampleRate) Hz")
        } catch {
            dlog("[Audio] continuing on the new input failed: \(error)")
        }
    }

    @MainActor
    private func observeHardwareChanges() {
        guard hardwareListener == nil else { return }
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.handleHardwareChange() }
        }
        hardwareListener = listener
        for selector in [
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioHardwarePropertyDevices
        ] {
            var address = AudioInputDevices.globalAddress(selector)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        }
    }

    private func startDrainTimer() {
        let timer = DispatchSource.makeTimerSource(queue: drainQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(20))
        timer.setEventHandler { [weak self] in self?.drainCapturedAudio() }
        timer.resume()
        drainTimer = timer
    }

    private func drainCapturedAudio() {
        let deviceSamples = capture.drain()
        guard !deviceSamples.isEmpty, let converter else { return }
        if let requestedAt = awaitingFirstBufferSince {
            awaitingFirstBufferSince = nil
            dlog("[Audio] first audio \(ContinuousClock.now - requestedAt) after the hotkey")
        }
        append(converter.convert(deviceSamples))
        publishLevel(of: deviceSamples)
    }

    private func finishConversion() {
        drainCapturedAudio()
        if let converter {
            append(converter.flush())
        }
        converter = nil
        awaitingFirstBufferSince = nil
    }

    private func append(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        bufferLock.withLock {
            let remaining = maxSamples - audioBuffer.count
            if remaining > 0 {
                audioBuffer.append(contentsOf: samples.prefix(remaining))
            }
        }
    }

    private func publishLevel(of samples: [Float]) {
        var sumOfSquares: Float = 0
        vDSP_svesq(samples, 1, &sumOfSquares, vDSP_Length(samples.count))
        let rms = sqrt(sumOfSquares / Float(samples.count))
        DispatchQueue.main.async { [weak self] in
            guard let self, isRecording else { return }
            audioLevel = rms
        }
    }
}
