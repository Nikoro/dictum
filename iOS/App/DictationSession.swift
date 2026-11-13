import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class DictationSession {
    var useUltra = true
    private(set) var preparing = false
    private(set) var modelReady = false
    let preparation = ModelPreparation()
    private(set) var session = KeyboardSession(id: UUID(), updatedAt: .distantPast, phase: .inactive)
    private(set) var errorMessage: String?
    private(set) var starting = false
    private(set) var isSuspended = false
    private(set) var captureSummary = AudioCaptureSummary()
    private(set) var installations: [IOSSpeechModel: IOSModelInstallation] = [:]

    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let speech = LocalSpeechEngine()
    @ObservationIgnored private let microphone = SessionMicrophone()
    @ObservationIgnored private(set) var preparationTask: Task<Void, Never>?
    @ObservationIgnored private var sessionTask: Task<Void, Never>?
    @ObservationIgnored private var transcriptionTask: Task<Void, Never>?
    @ObservationIgnored private var mailbox: KeyboardMailbox?
    @ObservationIgnored private var recordingStartedAt: Date?
    @ObservationIgnored private var resultCreatedAt: Date?
    @ObservationIgnored private var idleTimer = DictationIdleTimer()

    var isActive: Bool {
        session.phase != .inactive
    }

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        useUltra = preferences.object(forKey: "ios.useUltra") as? Bool ?? true
        microphone.onInterruption = { [weak self] in self?.endSession() }
        if let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: KeyboardMailbox.appGroup) {
            mailbox = try? KeyboardMailbox(directory: root.appendingPathComponent("KeyboardSession", isDirectory: true))
            try? mailbox?.clear()
        }
    }

    func prepareModel() {
        guard !preparing, !isActive, !starting else { return }
        preparing = true
        modelReady = false
        errorMessage = nil
        preparation.begin()
        preparationTask = Task { [weak self, speech, ultra = useUltra] in
            defer {
                self?.preparation.finish()
                self?.preparing = false
                self?.preparationTask = nil
            }
            do {
                try await speech.prepare(ultra: ultra) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.preparation.update(progress)
                    }
                }
                try Task.checkCancellation()
                self?.preparation.storageBytes = await speech.storageBytes(ultra: ultra)
                try Task.checkCancellation()
                self?.modelReady = true
                await self?.refreshModelInventory()
            } catch is CancellationError {
                self?.errorMessage = nil
            } catch {
                self?.errorMessage = String(localized: "ios.error.model")
            }
        }
    }

    func selectModel() {
        preferences.set(useUltra, forKey: "ios.useUltra")
        endSession()
        modelReady = false
    }

    func startSession() async {
        guard modelReady, !preparing, !isActive, !starting else { return }
        errorMessage = nil
        starting = true
        defer { starting = false }
        guard mailbox != nil else {
            errorMessage = String(localized: "ios.error.group")
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            errorMessage = String(localized: "ios.error.permission")
            return
        }
        do {
            try microphone.activate()
            try mailbox?.clear()
            session = KeyboardSession(id: UUID(), updatedAt: Date(), phase: .ready)
            idleTimer.reset()
            errorMessage = nil
            try publish()
            sessionTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                    guard let self, isActive else { return }
                    tick()
                }
            }
        } catch {
            endSession()
            errorMessage = String(localized: "ios.error.microphone")
        }
    }

    func endSession() {
        sessionTask?.cancel()
        sessionTask = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
        microphone.deactivate()
        idleTimer.reset()
        recordingStartedAt = nil
        resultCreatedAt = nil
        session = KeyboardSession(id: UUID(), updatedAt: Date(), phase: .inactive)
        do {
            try mailbox?.clear()
            try publish()
        } catch {
            errorMessage = String(localized: "ios.error.bridge")
        }
    }

    func startRecording(language: String? = nil) {
        guard session.phase == .ready else { return }
        do {
            try microphone.beginRecording()
            idleTimer.reset()
            recordingStartedAt = Date()
            captureSummary = AudioCaptureSummary()
            session.issue = nil
            errorMessage = nil
            resultCreatedAt = nil
            session.recordingID = UUID()
            session.languageCode = KeyboardLanguageHint.code(from: language) ?? "pl"
            session.phase = .recording
            try publish()
        } catch {
            endSession()
            errorMessage = String(localized: "ios.error.microphone")
        }
    }

    func stopRecording() {
        guard session.phase == .recording else { return }
        do {
            guard let file = try microphone.finishRecording() else {
                discardResult()
                return
            }
            captureSummary = microphone.captureSummary
            guard captureSummary.hasSignal else {
                discardResult()
                return
            }
            session.phase = .transcribing
            recordingStartedAt = nil
            try publish()
            transcribe(file: file)
        } catch {
            endSession()
            errorMessage = String(localized: "ios.error.microphone")
        }
    }

    func discardResult(issue: KeyboardSession.Issue? = nil) {
        guard session.phase == .result || session.phase == .recording else { return }
        microphone.discardRecording()
        recordingStartedAt = nil
        resultCreatedAt = nil
        session.clearResult(issue: issue)
        do { try publish() } catch { endSession() }
    }
}

extension DictationSession {
    private func transcribe(file: URL) {
        let sessionID = session.id
        let languageCode = session.languageCode ?? "pl"
        transcriptionTask = Task { [weak self, speech] in
            defer { try? FileManager.default.removeItem(at: file) }
            do {
                let text = try await speech.transcribe(file: file, languageCode: languageCode)
                try Task.checkCancellation()
                guard let self, session.id == sessionID else { return }
                session.completeTranscription(text)
                resultCreatedAt = session.phase == .result ? Date() : nil
                try publish()
            } catch is CancellationError {
                return
            } catch {
                guard let self, session.id == sessionID else { return }
                endSession()
                errorMessage = String(localized: "ios.error.transcription")
            }
        }
    }

    private func tick() {
        guard microphone.isRunning else {
            endSession()
            return
        }
        if session.phase == .recording {
            captureSummary = microphone.captureSummary
        }
        do {
            for command in try mailbox?.takeCommands() ?? [] where session.accepts(command, at: Date()) {
                handle(command)
            }
            if let recordingStartedAt, Date().timeIntervalSince(recordingStartedAt) >= 180 {
                stopRecording()
            }
            if let resultCreatedAt, Date().timeIntervalSince(resultCreatedAt) >= 60 {
                discardResult(issue: .resultExpired)
            }
            if idleTimer.hasExpired(phase: session.phase, at: Date()) {
                isSuspended = true
                endSession()
                return
            }
            try publish()
        } catch {
            endSession()
            errorMessage = String(localized: "ios.error.bridge")
        }
    }

    private func handle(_ command: KeyboardCommand) {
        switch command.action {
        case .start: startRecording(language: command.language)
        case .stop: stopRecording()
        case .cancel, .consume: discardResult()
        }
    }

    private func publish() throws {
        session.updatedAt = Date()
        try mailbox?.publish(session)
    }
}

extension DictationSession {
    func refreshModelInventory() async {
        installations = await speech.installations()
    }

    func setMicrophoneEnabled(_ enabled: Bool) async {
        isSuspended = !enabled
        if enabled {
            await activate()
        } else {
            endSession()
        }
    }
}
