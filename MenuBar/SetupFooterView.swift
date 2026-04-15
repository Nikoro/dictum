import SwiftUI

@MainActor
struct SetupFooterView: View {
    var body: some View {
        HStack {
            Button(action: { NSApplication.shared.terminate(nil) }, label: {
                Image(systemName: "power")
            })
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)

            Spacer()

            Text(String(format: String(localized: "footer.version", defaultValue: "Version: %@"), dictumAppVersion))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Color.clear
                .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}
