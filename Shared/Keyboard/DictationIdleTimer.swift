import Foundation

struct DictationIdleTimer {
    private var idleSince: Date?
    static let defaultMinutes = 15
    static let choices = [1, 5, 10, 15, 30, 60, 0]

    func interrupted(phase: KeyboardSession.Phase, at date: Date) -> Self? {
        guard phase == .ready else { return nil }
        return Self(idleSince: idleSince ?? date)
    }

    mutating func hasExpired(phase: KeyboardSession.Phase, at date: Date, minutes: Int = defaultMinutes) -> Bool {
        guard phase == .ready else {
            reset()
            return false
        }
        guard let idleSince else {
            idleSince = date
            return false
        }
        return minutes > 0 && date.timeIntervalSince(idleSince) >= TimeInterval(minutes) * 60
    }

    mutating func reset() {
        idleSince = nil
    }
}
