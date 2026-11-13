import SwiftUI

struct KeyboardEmojiKey: UIViewRepresentable {
    let model: KeyboardModel
    let palette: KeyboardPalette
    let insert: (String) -> Void
    let open: () -> Void

    func makeUIView(context: Context) -> KeyboardAccentKeyControl {
        KeyboardAccentKeyControl()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: KeyboardAccentKeyControl, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 44, height: proposal.height ?? 43)
    }

    func updateUIView(_ control: KeyboardAccentKeyControl, context: Context) {
        let capacity = QuickEmojiChoices.capacity(width: max(model.keyboardFrame.width, 320))
        let personal = model.emojiPreferences.frequent(limit: capacity).filter { EmojiCatalog.shared.entry(for: $0) != nil }
        control.configure(
            choices: QuickEmojiChoices.filling(personal, limit: capacity), palette: palette, model: model, tap: open
        ) { symbol in
            insert(symbol)
            model.emojiPreferences.record(symbol)
            model.emojiSearchActive = false
            model.emoji = false
        }
    }

    static func dismantleUIView(_ control: KeyboardAccentKeyControl, coordinator: ()) {
        control.cancel()
    }
}
