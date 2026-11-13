import SwiftUI

@MainActor
struct DownloadedLLMModelPicker: View {
    let models: [DownloadedLLMModel]
    let selectedModelId: String
    let onSelectModel: (String) -> Void

    var body: some View {
        VStack(spacing: 2) {
            ForEach(models) { model in
                Button {
                    onSelectModel(model.id)
                } label: {
                    row(for: model, isSelected: model.id == selectedModelId)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func row(for model: DownloadedLLMModel, isSelected: Bool) -> some View {
        HStack {
            Image(systemName: isSelected ? "circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color("AccentColor") : .secondary)
                .font(.caption2)

            VStack(alignment: .leading, spacing: 1) {
                Text(model.shortName)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text(model.formattedSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}
