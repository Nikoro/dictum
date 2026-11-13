import SwiftUI

struct KeyboardMetrics {
    let width: CGFloat
    var tablet = false
    var landscape = false
    let compact: Bool
    var noticeHeight: CGFloat = 0
    var emojiSearchActive = false
    var accentTopInset: CGFloat = 0
    var emojiVisible = false

    var keyHeight: CGFloat {
        compact ? 32 : 43
    }

    var rowSpacing: CGFloat {
        compact ? 7 : 11
    }

    var headerHeight: CGFloat {
        noticeHeight
    }

    var keyWidth: CGFloat {
        (width - 13 - 9 * 6) / 10
    }

    var modifierWidth: CGFloat {
        keyWidth + 12
    }

    var bottomModifierWidth: CGFloat {
        width * 0.108
    }

    var returnWidth: CGFloat {
        tablet ? (width - 30) / 4 : modifierWidth
    }

    var dictationWidth: CGFloat {
        44
    }

    var height: CGFloat {
        if tablet {
            return headerHeight + (emojiVisible && !emojiSearchActive ? (landscape ? 398 : 316)
                : KeyboardKeyLayout(width: width, tablet: true, landscape: landscape).height
                + (emojiSearchActive ? 147 : 0) + accentTopInset)
        }
        if emojiVisible, !emojiSearchActive {
            return headerHeight + (compact ? 216 : 313)
        }
        return headerHeight + 11 + 4 * keyHeight + 3 * rowSpacing
            + (emojiSearchActive ? 147 : 0) + accentTopInset
    }
}

struct KeyboardPalette {
    let dark: Bool

    var background: Color {
        dark ? Color(white: 23 / 255) : Color(red: 0.82, green: 0.83, blue: 0.85)
    }

    var key: Color {
        dark ? Color(white: 0.75).opacity(0.225) : .white
    }

    var modifier: Color {
        dark ? key : Color(red: 0.67, green: 0.69, blue: 0.73)
    }

    var foreground: Color {
        dark ? .white : .black
    }

    var hint: Color {
        foreground.opacity(0.35)
    }

    var pressedKey: Color {
        dark ? Color(white: 0.75).opacity(0.17) : Color(white: 0.7)
    }
}

struct KeyboardKeyStyle: ButtonStyle {
    let palette: KeyboardPalette
    var modifier = false
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(selected ? .black : palette.foreground)
            .background(fill(pressed: configuration.isPressed), in: .rect(cornerRadius: 8))
            .shadow(color: .black.opacity(palette.dark ? 0 : 0.25), radius: 0, y: 1)
            .contentShape(.rect)
    }

    private func fill(pressed: Bool) -> Color {
        if selected {
            return pressed ? Color(white: 0.8) : .white
        }
        if pressed {
            return palette.pressedKey
        }
        return modifier ? palette.modifier : palette.key
    }
}
