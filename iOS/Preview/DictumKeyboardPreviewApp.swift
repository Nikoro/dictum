import SwiftUI

@main
struct DictumKeyboardPreviewApp: App {
    var body: some Scene {
        WindowGroup { KeyboardPreviewScreen() }
    }
}

private struct KeyboardPreviewScreen: View {
    @State private var model = KeyboardModel.recordingPreview()
    @State private var text = ""
    @State private var colored = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                Text(String(localized: "ios.preview.title")).font(.title2.bold())
                Toggle(String(localized: "ios.preview.colored"), isOn: $colored)
                TextField(String(localized: "ios.test_field"), text: $text)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("preview-editor")
                Text(String(localized: "ios.preview.recording")).font(.footnote)
                HStack(spacing: 6) {
                    KeyboardCharacterKey(character: "a", uppercase: true, palette: palette, model: model) { _ in }
                        .frame(width: 33.5, height: 43)
                    DictationKey(model: model, palette: palette) {}
                        .frame(width: 44, height: 43)
                    KeyboardEmojiGlyph(palette: palette)
                        .frame(width: 43.3, height: 43)
                        .background(palette.key, in: .rect(cornerRadius: 8))
                }
                Spacer()
            }
            .padding(20)
        }
    }

    @ViewBuilder private var background: some View {
        if colored {
            LinearGradient(colors: [.red, .blue, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color(uiColor: .systemBackground)
        }
    }

    private var palette: KeyboardPalette {
        KeyboardPalette(dark: colorScheme == .dark)
    }
}
