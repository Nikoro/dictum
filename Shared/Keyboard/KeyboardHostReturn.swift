import Foundation

@MainActor enum KeyboardHostReturn {
    static func perform(
        activation: URL,
        activate: () async -> Bool,
        open: (URL) async -> Void
    ) async {
        let ready = await activate()
        guard ready, !Task.isCancelled, let destination = KeyboardActivationLink.destination(from: activation) else { return }
        await open(destination)
    }
}
