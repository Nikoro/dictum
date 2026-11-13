import SwiftUI

struct KeyboardEmojiGlyph: View {
    let palette: KeyboardPalette

    var body: some View {
        Image("KeyboardEmojiFace")
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(palette.foreground)
            .frame(width: 19, height: 19)
            .accessibilityHidden(true)
    }
}
