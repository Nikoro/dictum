import Foundation

@MainActor enum KeyboardHostReturn {
    static func perform(
        activation: URL,
        isForeground: () -> Bool = { true },
        isReady: () -> Bool = { true },
        wait: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        activate: () async -> Bool,
        open: (URL) async -> Void
    ) async {
        guard await foreground(isForeground, wait: wait) else { return }
        let ready = await activate()
        guard ready, await foreground(isForeground, wait: wait), isReady(), !Task.isCancelled,
              let destination = KeyboardActivationLink.destination(from: activation) else { return }
        await open(destination)
    }

    private static func foreground(
        _ isForeground: () -> Bool,
        wait: @MainActor (Duration) async throws -> Void
    ) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        for _ in 0 ..< 100 {
            guard !Task.isCancelled, ContinuousClock.now < deadline else { return false }
            if isForeground() {
                return true
            }
            do { try await wait(.milliseconds(100)) } catch { return false }
        }
        return false
    }
}
