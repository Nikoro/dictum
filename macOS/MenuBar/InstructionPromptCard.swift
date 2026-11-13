import SwiftUI

@MainActor
struct InstructionPromptCard<Icon: View, Accessory: View>: View {
    let title: String
    let isEnabled: Bool
    let hasDownloadedModels: Bool
    let placeholder: String
    @Binding var prompt: String
    let onEnabledChange: (Bool) -> Void
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let accessory: () -> Accessory
    @State private var showNoModelWarning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                icon()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                Spacer()
                accessory()
                Toggle("", isOn: enabledBinding)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.mini)
            }

            if showNoModelWarning {
                Text(String(localized: "section.prompt.nomodel", defaultValue: "Download an LLM model first, e.g. Gemma 4 E2B"))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if isEnabled {
                PromptTextEditor(text: $prompt, placeholder: placeholder)
                    .frame(minHeight: 60, maxHeight: 100)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onChange(of: hasDownloadedModels) { _, hasModels in
            if hasModels {
                showNoModelWarning = false
            }
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { isEnabled },
            set: { newValue in
                if newValue, !hasDownloadedModels {
                    showNoModelWarning = true
                } else {
                    showNoModelWarning = false
                    onEnabledChange(newValue)
                }
            }
        )
    }
}
