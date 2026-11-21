import Foundation

@MainActor
struct KeyboardRenderState: Equatable {
    let layout: KeyboardKeyLayout
    let dark: Bool
    let shift: KeyboardShiftState.Mode
    let phase: KeyboardSession.Phase?
    let pending: Bool
    let canUndo: Bool
    let canRedo: Bool
    let quickEmoji: [String]

    init(layout: KeyboardKeyLayout, model: KeyboardModel, dark: Bool) {
        self.layout = layout
        self.dark = dark
        shift = model.shift.mode
        phase = model.session?.phase
        pending = model.pending
        canUndo = model.canUndo
        canRedo = model.canRedo
        quickEmoji = model.emojiPreferences.frequent(limit: QuickEmojiChoices.capacity(width: layout.width))
    }
}

@MainActor
extension KeyboardKeyLayout {
    init(model: KeyboardModel, width: CGFloat) {
        self.init(
            width: width,
            tablet: model.tabletLayout,
            landscape: model.landscapeLayout || model.compactLayout,
            numbers: model.numbers,
            symbols: model.symbols,
            needsSwitch: model.needsInputModeSwitchKey
        )
    }
}

@MainActor
extension KeyboardMetrics {
    init(model: KeyboardModel, width: CGFloat) {
        self.init(
            width: width,
            tablet: model.tabletLayout,
            landscape: model.landscapeLayout,
            compact: model.compactLayout,
            noticeHeight: model.noticeHeight(for: width),
            emojiSearchActive: model.emoji && model.emojiSearchActive,
            accentTopInset: model.accentPopup?.topInset ?? 0,
            emojiVisible: model.emoji
        )
    }
}
