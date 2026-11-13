import SwiftUI

struct KeyboardView: View {
    @Bindable var model: KeyboardModel
    let insert: (String) -> Void
    let start: () -> Void
    let nextKeyboard: () -> Void
    let dismiss: () -> Void
    var nativeInput = false
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            keyboardContent(metrics: metrics(width: geometry.size.width))
        }
        .onAppear {
            let action = openURL
            model.openURL = { action($0) }
        }
        .onDisappear { model.openURL = nil }
        .onChange(of: model.emoji) { model.keysChanged() }
        .onChange(of: model.emojiSearchActive) { model.keysChanged() }
    }

    private func keyboardContent(metrics: KeyboardMetrics) -> some View {
        VStack(spacing: 0) {
            if metrics.accentTopInset > 0 {
                Color.clear.frame(height: metrics.accentTopInset)
            }
            notice(metrics: metrics)
            if model.emoji {
                EmojiBrowserView(model: model, palette: palette, insert: insert)
                    .frame(height: model.emojiSearchActive ? 147 : metrics.height - metrics.headerHeight)
            }
            if !model.emoji || model.emojiSearchActive {
                keyPlane(width: metrics.width)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .topLeading) {
            if let popup = model.accentPopup {
                KeyboardAccentPopup(selection: popup, palette: palette)
                    .offset(
                        x: popup.frame.minX - popup.keyboardOrigin.x,
                        y: popup.frame.minY - popup.keyboardOrigin.y + popup.topInset
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder private func keyPlane(width: CGFloat) -> some View {
        if nativeInput {
            Color.clear.frame(height: keyLayout(width: width).height)
        } else {
            hostedKeyPlane(width: width)
        }
    }

    private func hostedKeyPlane(width: CGFloat) -> some View {
        KeyboardKeyPlane(
            layout: keyLayout(width: width),
            model: model,
            palette: palette,
            insert: insert,
            start: start,
            nextKeyboard: nextKeyboard,
            dismiss: dismiss
        ) {
            if let url = model.activationURLProvider() ?? model.activationURL {
                openURL(url)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: keyLayout(width: width).height)
    }

    @ViewBuilder private func notice(metrics: KeyboardMetrics) -> some View {
        if let notice = model.notice {
            HStack(alignment: .top, spacing: KeyboardNoticeLayout.spacing) {
                Text(notice)
                    .font(.system(size: KeyboardNoticeLayout.fontSize))
                    .foregroundStyle(palette.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, KeyboardNoticeLayout.verticalPadding)
                Button(String(localized: "ios.keyboard.dismiss_error"), systemImage: "xmark") {
                    model.dismissNotice()
                }
                .labelStyle(.iconOnly)
                .frame(width: KeyboardNoticeLayout.closeWidth, height: KeyboardNoticeLayout.closeWidth)
                .contentShape(.rect)
                .buttonStyle(.plain)
                .accessibilityIdentifier("dismiss-keyboard-error")
            }
            .padding(.horizontal, KeyboardNoticeLayout.horizontalPadding)
            .frame(height: metrics.headerHeight)
            .accessibilityIdentifier("keyboard-error")
        }
    }

    private func metrics(width: CGFloat) -> KeyboardMetrics {
        KeyboardMetrics(
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

    private func keyLayout(width: CGFloat) -> KeyboardKeyLayout {
        KeyboardKeyLayout(
            width: width,
            tablet: model.tabletLayout,
            landscape: model.landscapeLayout || model.compactLayout,
            numbers: model.numbers,
            symbols: model.symbols,
            needsSwitch: model.needsInputModeSwitchKey
        )
    }

    private var palette: KeyboardPalette {
        KeyboardPalette(dark: colorScheme == .dark)
    }
}
