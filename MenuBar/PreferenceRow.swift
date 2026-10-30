import SwiftUI

// Edge case: a popup Picker keeps its intrinsic width inside a wider frame and centers itself,
// so the control frame is trailing-aligned to keep every row's right edge on one line.
@MainActor
struct PreferenceRow<Control: View>: View {
    let title: String
    var maxControlWidth: CGFloat = 200
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 0)
            control
                .frame(maxWidth: maxControlWidth, alignment: .trailing)
        }
        .frame(minHeight: 22)
    }
}
