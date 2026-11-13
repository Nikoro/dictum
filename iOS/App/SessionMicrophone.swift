import AVFoundation
import Foundation

@MainActor
final class SessionMicrophone {
    var onInterruption: (() -> Void)?
    private var interruptionObserver: NSObjectProtocol?
    private var engine: AVAudioEngine?
    private let sink = RecordingSink()
    private var hasTap = false
    private(set) var recordingURL: URL?

    init() {
        let temporary = FileManager.default.temporaryDirectory
        let files = (try? FileManager.default.contentsOfDirectory(at: temporary, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("dictum-") && file.pathExtension == "caf" {
            try? FileManager.default.removeItem(at: file)
        }
    }

    func activate() throws {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onInterruption?() }
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try session.setActive(true)
        let engine = AVAudioEngine()
        self.engine = engine
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CocoaError(.fileReadUnknown) }
        AudioRecordingTap.install(on: input, format: nil, sink: sink)
        hasTap = true
        engine.prepare()
        try engine.start()
        try AVAudioApplication.shared.setInputMuted(true)
    }

    func beginRecording() throws {
        guard let engine, engine.isRunning else { throw CocoaError(.fileReadUnknown) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dictum-" + UUID().uuidString + ".caf")
        recordingURL = url
        try sink.begin(url: url, format: engine.inputNode.outputFormat(forBus: 0))
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: url.path)
        try AVAudioApplication.shared.setInputMuted(false)
    }

    func finishRecording() throws -> URL? {
        try AVAudioApplication.shared.setInputMuted(true)
        try sink.finish()
        return recordingURL
    }

    func discardRecording() {
        do {
            try AVAudioApplication.shared.setInputMuted(true)
        } catch {
            deactivate()
            return
        }
        removeRecording()
    }

    private func removeRecording() {
        try? sink.finish()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
    }

    func deactivate() {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        engine?.stop()
        if hasTap {
            engine?.inputNode.removeTap(onBus: 0)
        }
        engine = nil
        hasTap = false
        removeRecording()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        try? AVAudioApplication.shared.setInputMuted(false)
    }

    var captureSummary: AudioCaptureSummary {
        sink.summary
    }

    var isRunning: Bool {
        engine?.isRunning == true
    }
}
