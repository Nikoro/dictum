import SwiftUI

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
