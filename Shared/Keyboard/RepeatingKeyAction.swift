import Foundation

@MainActor
final class RepeatingKeyAction {
    private let action: () -> Void
    private let initialDelay: Duration
    private let interval: Duration
    private let wait: @Sendable (Duration) async throws -> Void
    private var task: Task<Void, Never>?

    init(
        initialDelay: Duration = .milliseconds(500),
        interval: Duration = .milliseconds(100),
        wait: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        action: @escaping () -> Void
    ) {
        self.action = action
        self.initialDelay = initialDelay
        self.interval = interval
        self.wait = wait
    }

    func press() {
        guard task == nil else { return }
        action()
        task = Task { [weak self, wait, initialDelay, interval] in
            do {
                try await wait(initialDelay)
                while !Task.isCancelled, self != nil {
                    self?.action()
                    try await wait(interval)
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
