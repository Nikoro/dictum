import SwiftUI

@MainActor
struct DownloadedLLMModelsList: View {
    let models: [DownloadedLLMModel]
    let selectedModelId: String
    let onSelectModel: (String) -> Void
    let onDeleteModel: (DownloadedLLMModel) -> Void

    var body: some View {
        ForEach(models) { model in
            Button {
                onSelectModel(model.id)
            } label: {
                HStack {
                    Image(systemName: model.id == selectedModelId ? "circle.fill" : "circle")
                        .foregroundStyle(model.id == selectedModelId ? Color("AccentColor") : .secondary)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.shortName)
                            .font(.caption)
                        Text("LLM")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(model.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        onDeleteModel(model)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }
}
