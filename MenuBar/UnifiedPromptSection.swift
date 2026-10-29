import SwiftUI

@MainActor
struct UnifiedPromptSection: View {
    @Environment(AppSettings.self) private var settings
    @State private var localPrompt: String = ""
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            if isExpanded {
                expandedContent
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .onAppear {
            localPrompt = settings.unifiedSystemPrompt.isEmpty
                ? DefaultPrompts.unified
                : settings.unifiedSystemPrompt
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain.head.profile")
                .frame(width: 18, height: 18)

            Text(String(localized: "section.prompt.unified", defaultValue: "System prompt"))
                .font(.caption)
                .fontWeight(.medium)

            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        HStack {
            Spacer()
            Button(String(localized: "section.prompt.unified.reset", defaultValue: "Reset")) {
                settings.resetUnifiedPrompt()
                localPrompt = DefaultPrompts.unified
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(Color("AccentColor"))
        }

        PromptTextEditor(
            text: $localPrompt,
            placeholder: String(DefaultPrompts.unified.prefix(100)) + "..."
        )
        .frame(minHeight: 100, maxHeight: 160)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onChange(of: localPrompt) { _, newValue in
            // Edge case: store only a real override. The editor is seeded with the default, and
            // saving that verbatim would freeze the user on today's wording.
            settings.unifiedSystemPrompt =
                newValue == DefaultPrompts.unified ? "" : newValue
        }
    }
}
