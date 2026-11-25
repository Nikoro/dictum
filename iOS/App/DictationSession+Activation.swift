import Foundation

extension DictationSession {
    var isActive: Bool {
        session.phase != .inactive
    }

    func chooseModel(_ model: IOSSpeechModel) async {
        guard useUltra != model.usesUltra, !preparing, !starting,
              session.phase != .recording, session.phase != .transcribing else { return }
        useUltra = model.usesUltra
        selectModel()
        prepareModel()
        await preparationTask?.value
        guard modelReady, !isSuspended, !Task.isCancelled else { return }
        await startSession()
    }

    func activate() async {
        guard !isSuspended, !isActive, interruptedStandby == nil else { return }
        if !modelReady {
            prepareModel()
            await preparationTask?.value
        }
        guard modelReady, !Task.isCancelled, !isSuspended else { return }
        await startSession()
    }

    func interruptSession() {
        guard isActive || starting else { return }
        let standby = idleTimer.interrupted(phase: session.phase, at: Date())
        endSession()
        interruptedStandby = standby
    }

    func finishInterruption(shouldResume: Bool) {
        guard var timer = interruptedStandby else { return }
        interruptedStandby = nil
        guard !timer.hasExpired(phase: .ready, at: Date(), minutes: standbyMinutes) else {
            isSuspended = true
            return
        }
        guard shouldResume, !isSuspended, !isActive, !starting, modelReady else { return }
        beginStandby(timer: timer)
    }

    func setMicrophoneEnabled(_ enabled: Bool) async {
        isSuspended = !enabled
        if enabled {
            interruptedStandby = nil
            await activate()
        } else {
            endSession()
        }
    }
}
