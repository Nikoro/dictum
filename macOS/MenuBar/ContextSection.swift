import SwiftUI

@MainActor
struct ContextSection: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "section.context", defaultValue: "Context"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            ContextToggleRow(
                icon: "rectangle.dashed.badge.record",
                title: String(localized: "section.context.screenshot", defaultValue: "Screenshot"),
                isOn: Bindable(settings).contextScreenshot
            )
            ContextToggleRow(
                icon: "text.cursor",
                title: String(localized: "section.context.selectedText", defaultValue: "Selected text"),
                isOn: Bindable(settings).contextSelectedText
            )
            ContextToggleRow(
                icon: "doc.on.clipboard",
                title: String(localized: "section.context.clipboard", defaultValue: "Clipboard"),
                isOn: Bindable(settings).contextClipboard
            )
        }
    }
}

@MainActor
struct ContextToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundStyle(isOn ? .primary : .secondary)
                .font(.caption)
            Text(title)
                .font(.caption)
                .foregroundStyle(isOn ? .primary : .secondary)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
        }
    }
}
