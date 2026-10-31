import AVFoundation
import CoreAudio
@testable import Dictum
import Testing

struct HALInputCaptureTests {
    private static let builtInMicrophone = AudioInputDevices.all().first { $0.uid == "BuiltInMicrophoneDevice" }

    @Test(.enabled(if: builtInMicrophone != nil, "needs a Mac with a built-in microphone"))
    func `prepared capture stays bound to the chosen device instead of the system default`() throws {
        let microphone = try #require(Self.builtInMicrophone)
        let capture = HALInputCapture()
        defer { capture.teardown() }

        try capture.prepare(deviceID: microphone.id)

        #expect(capture.boundDeviceID == microphone.id)
        #expect(capture.isPrepared(for: microphone.id))
        #expect(capture.sampleRate > 0)
    }

    @Test(.enabled(
        if: builtInMicrophone != nil && AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
        "needs a built-in microphone and microphone access"
    ))
    func `audio arrives right after start, not seconds later`() async throws {
        let microphone = try #require(Self.builtInMicrophone)
        let capture = HALInputCapture()
        defer { capture.teardown() }
        try capture.prepare(deviceID: microphone.id)

        let started = ContinuousClock.now
        try capture.start()
        var received = 0
        while received == 0, ContinuousClock.now - started < .seconds(2) {
            try await Task.sleep(for: .milliseconds(5))
            received += capture.drain().count
        }
        capture.stop()

        #expect(received > 0)
        #expect(ContinuousClock.now - started < .milliseconds(300))
    }

    @Test
    func `ring buffer hands every written sample to the reader once, in order`() {
        let ring = SampleRing(capacity: 8)
        let first: [Float] = [1, 2, 3, 4, 5]
        let second: [Float] = [6, 7, 8, 9]

        first.withUnsafeBufferPointer { #expect(ring.write($0)) }
        #expect(ring.readAll() == first)
        second.withUnsafeBufferPointer { #expect(ring.write($0)) }

        #expect(ring.readAll() == second)
        #expect(ring.readAll().isEmpty)
    }

    @Test
    func `ring buffer refuses a write that would overwrite unread samples`() {
        let ring = SampleRing(capacity: 4)
        let samples: [Float] = [1, 2, 3]

        samples.withUnsafeBufferPointer { #expect(ring.write($0)) }

        samples.withUnsafeBufferPointer { #expect(!ring.write($0)) }
        #expect(ring.readAll() == samples)
    }
}
