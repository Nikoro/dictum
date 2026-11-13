import SwiftUI

struct DictationKey: View {
    @Bindable var model: KeyboardModel
    let palette: KeyboardPalette
    var height: CGFloat = 43
    let start: () -> Void

    var body: some View {
        action.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var action: some View {
        if let session = model.session {
            switch session.phase {
            case .ready:
                Button(action: start) { logo }
                    .accessibilityLabel(String(localized: "ios.record"))
                    .disabled(model.pending)
            case .recording:
                Button { model.send(.stop) } label: {
                    RoundedRectangle(cornerRadius: 4).fill(.red).frame(width: 16, height: 16)
                }
                .buttonStyle(KeyboardKeyStyle(palette: palette))
                .accessibilityLabel(String(localized: "ios.stop"))
                .disabled(model.pending)
            case .transcribing, .result:
                ProgressView()
                    .accessibilityLabel(String(localized: "ios.status.transcribing"))
            case .inactive:
                openApp
            }
        } else {
            openApp
        }
    }

    @ViewBuilder private var openApp: some View {
        if let url = URL(string: "dictum://session") {
            Link(destination: url) { logo }
                .accessibilityLabel(String(localized: "ios.keyboard.open"))
        }
    }

    private var logo: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFill()
            .frame(width: 44, height: height)
            .clipShape(.rect(cornerRadius: 8))
    }
}
