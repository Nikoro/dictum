import Foundation

extension DictationSession {
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
        guard !isSuspended, !isActive else { return }
        if !modelReady {
            prepareModel()
            await preparationTask?.value
        }
        guard modelReady, !Task.isCancelled, !isSuspended else { return }
        await startSession()
    }
}
