import Foundation

@MainActor
final class RepeatingKeyAction {
    private let action: () -> Void
    private let initialDelay: Duration
    private let interval: Duration
    private let acceleratedInterval: Duration
    private let accelerationAfter: Int
    private let acceleratedAction: (() -> Void)?
    private let wait: @Sendable (Duration) async throws -> Void
    private var task: Task<Void, Never>?

    init(
        initialDelay: Duration = .milliseconds(500),
        interval: Duration = .milliseconds(100),
        acceleratedInterval: Duration = .milliseconds(200),
        accelerationAfter: Int = 20,
        wait: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        acceleratedAction: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.action = action
        self.initialDelay = initialDelay
        self.interval = interval
        self.acceleratedInterval = acceleratedInterval
        self.accelerationAfter = accelerationAfter
        self.acceleratedAction = acceleratedAction
        self.wait = wait
    }

    func press() {
        guard task == nil else { return }
        action()
        task = Task { [weak self, wait, initialDelay, interval, acceleratedInterval, accelerationAfter] in
            do {
                try await wait(initialDelay)
                var repetitions = 0
                while !Task.isCancelled, self != nil {
                    let accelerated = repetitions >= accelerationAfter
                    if accelerated, let action = self?.acceleratedAction {
                        action()
                    } else {
                        self?.action()
                    }
                    repetitions += 1
                    try await wait(accelerated ? acceleratedInterval : interval)
                }
            } catch {}
        }
    }

    func release() {
        task?.cancel()
        task = nil
    }

    deinit { task?.cancel() }
}
