import Foundation

struct DictationIdleTimer {
    private var idleSince: Date?
    let timeout: TimeInterval = 300

    mutating func hasExpired(phase: KeyboardSession.Phase, at date: Date) -> Bool {
        guard phase == .ready else {
            reset()
            return false
        }
        guard let idleSince else {
            idleSince = date
            return false
        }
        return date.timeIntervalSince(idleSince) >= timeout
    }

    mutating func reset() {
        idleSince = nil
    }
}
