import SwiftUI

@MainActor
struct SetupHeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image("AppLogo")
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("Dictum")
                .font(.title.bold())
            Text(String(localized: "setup.title", defaultValue: "Setup"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}
