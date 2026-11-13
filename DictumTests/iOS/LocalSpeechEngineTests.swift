import AVFoundation
@testable import Dictum
import Foundation
import Testing
import UIKit

struct LocalSpeechEngineTests {
    @Test(arguments: [false, true])
    func `both models recognize a Polish recording with the keyboard language hint`(ultra: Bool) async throws {
        let file = try #require(Bundle(for: SpeechFixtureBundle.self).url(forResource: "polish", withExtension: "aiff"))
        let engine = LocalSpeechEngine()
        try await engine.prepare(ultra: ultra, progress: nil)
        let text = try await engine.transcribe(file: file, languageCode: "pl")
        #expect(!text.isEmpty)
        #expect(text.localizedCaseInsensitiveContains("polskiego"))
        #expect(!text.unicodeScalars.contains { (0x0400 ... 0x04FF).contains($0.value) })
    }
}

@Suite(.serialized)
struct MicrophoneCaptureTests {
    @MainActor @Test
    func `idle input is system muted and only dictation opens the microphone`() throws {
        let microphone = SessionMicrophone()
        let application = AVAudioApplication.shared
        defer { microphone.deactivate() }
        try microphone.activate()
        #expect(microphone.isRunning)
        #expect(application.isInputMuted)
        try microphone.beginRecording()
        #expect(!application.isInputMuted)
        _ = try microphone.finishRecording()
        #expect(application.isInputMuted)
        try microphone.beginRecording()
        #expect(!application.isInputMuted)
        microphone.discardRecording()
        #expect(application.isInputMuted)
        microphone.deactivate()
        #expect(!microphone.isRunning)
        #expect(!application.isInputMuted)
    }

    @MainActor @Test
    func `microphone capture delivers audio frames into a finalized recording`() async throws {
        let microphone = SessionMicrophone()
        defer { microphone.deactivate() }
        try microphone.activate()
        try microphone.beginRecording()
        let playback = try fixturePlayback()
        defer { playback.stop() }
        try await Task.sleep(for: .seconds(4))
        let url = try #require(try microphone.finishRecording())
        #expect(UIApplication.shared.isProtectedDataAvailable)
        let audioSession = AVAudioSession.sharedInstance()
        let application = AVAudioApplication.shared
        print("Audio diagnostics: frames=\(microphone.captureSummary.frames), peak=\(microphone.captureSummary.peak)")
        print("Audio diagnostics: permission=\(application.recordPermission.rawValue), muted=\(application.isInputMuted)")
        print("Audio diagnostics: routes=\(audioSession.currentRoute.inputs.map(\.portType.rawValue))")
        let file = try AVAudioFile(forReading: url)
        try #require(file.length > 0)
        let buffer = try #require(AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ))
        try file.read(into: buffer)
        let channel = try #require(buffer.floatChannelData?[0])
        let peak = (0 ..< Int(buffer.frameLength)).reduce(Float.zero) { max($0, abs(channel[$1])) }
        #expect(peak > 0)
        let engine = LocalSpeechEngine()
        try await engine.prepare(ultra: true, progress: nil)
        let text = try await engine.transcribe(file: url)
        let recognizedPolish = text.localizedCaseInsensitiveContains("polskiego")
        #expect(recognizedPolish)
    }

    @MainActor @Test
    func `native recorder captures the speaker fixture as an independent microphone baseline`() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
        let recorder = try AVAudioRecorder(url: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false
        ])
        recorder.isMeteringEnabled = true
        try #require(recorder.record())
        let playback = try fixturePlayback()
        defer { playback.stop() }
        try await Task.sleep(for: .seconds(4))
        recorder.updateMeters()
        print("Native recorder power: \(recorder.peakPower(forChannel: 0))")
        recorder.stop()
        let peak = try filePeak(at: url)
        print("Native recorder peak: \(peak)")
        #expect(peak > 0)
    }

    @MainActor @Test
    func `keyboard commands record and deliver Polish text through the complete app session`() async throws {
        let dictation = DictationSession()
        await dictation.activate()
        try #require(dictation.modelReady)
        defer { dictation.endSession() }
        try #require(dictation.session.phase == .ready)
        let originalSession = dictation.session.id
        await dictation.activate()
        #expect(dictation.session.id == originalSession)
        let root = try #require(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: KeyboardMailbox.appGroup))
        let mailbox = try KeyboardMailbox(directory: root.appendingPathComponent("KeyboardSession"))
        var delivery = KeyboardResultDelivery()
        let document = UUID()
        delivery.begin(sessionID: dictation.session.id, documentID: document)
        try send(.start, for: dictation.session, to: mailbox)
        try await waitUntil { dictation.session.phase == .recording }
        delivery.observe(dictation.session)
        let playback = try fixturePlayback()
        defer { playback.stop() }
        try await Task.sleep(for: .seconds(4))
        try send(.stop, for: dictation.session, to: mailbox)
        try await waitUntil {
            dictation.session.phase == .result || dictation.session.issue != nil || dictation.errorMessage != nil
        }
        try #require(dictation.session.phase == .result)
        assertAutomaticInsertion(&delivery, session: dictation.session, document: document)
        try send(.consume, for: dictation.session, to: mailbox)
        try await waitUntil { dictation.session.phase == .ready }
        #expect(dictation.session.transcript == nil)
    }

    @MainActor @Test
    func `model choice survives relaunch and microphone suspension is respected`() async throws {
        let name = UUID().uuidString
        let preferences = try #require(UserDefaults(suiteName: name))
        defer { preferences.removePersistentDomain(forName: name) }
        let dictation = DictationSession(preferences: preferences)
        dictation.useUltra = false
        dictation.selectModel()
        #expect(!DictationSession(preferences: preferences).useUltra)
        await dictation.setMicrophoneEnabled(false)
        await dictation.activate()
        #expect(!dictation.isActive)
        #expect(!dictation.preparing)
    }

    private func assertAutomaticInsertion(
        _ delivery: inout KeyboardResultDelivery,
        session: KeyboardSession,
        document: UUID
    ) {
        if case let .insert(text) = delivery.result(from: session, in: document, at: Date()) {
            let recognizedPolish = text.localizedCaseInsensitiveContains("polskiego")
            #expect(recognizedPolish)
        } else {
            Issue.record("The completed recording was not delivered automatically")
        }
        #expect(delivery.result(from: session, in: document, at: Date()) == .discard)
    }

    private func send(_ action: KeyboardCommand.Action, for session: KeyboardSession, to mailbox: KeyboardMailbox) throws {
        try mailbox.send(KeyboardCommand(sessionID: session.id, recordingID: session.recordingID, action: action))
    }

    private func filePeak(at url: URL) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        try #require(file.length > 0)
        let buffer = try #require(AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ))
        try file.read(into: buffer)
        let channel = try #require(buffer.floatChannelData?[0])
        return (0 ..< Int(buffer.frameLength)).reduce(Float.zero) { max($0, abs(channel[$1])) }
    }

    @MainActor private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(60))
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        try #require(condition())
    }

    @MainActor private func fixturePlayback() throws -> AVAudioPlayer {
        let url = try #require(Bundle(for: SpeechFixtureBundle.self).url(forResource: "polish", withExtension: "aiff"))
        let player = try AVAudioPlayer(contentsOf: url)
        player.volume = 1
        print("Audio diagnostics: speaker volume=\(AVAudioSession.sharedInstance().outputVolume)")
        try #require(player.play())
        return player
    }
}

private final class SpeechFixtureBundle: NSObject {}
