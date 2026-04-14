import SwiftUI

@MainActor
struct DownloadedWhisperModelsList: View {
    let models: [WhisperModelInfo]
    let activeModelId: String
    let onSelectModel: (String) -> Void
    let onDeleteModel: (WhisperModelInfo) -> Void

    var body: some View {
        ForEach(models) { model in
            Button {
                onSelectModel(model.id)
            } label: {
                HStack {
                    Image(systemName: model.id == activeModelId ? "circle.fill" : "circle")
                        .foregroundStyle(model.id == activeModelId ? Color("AccentColor") : .secondary)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.displayName)
                            .font(.caption)
                        Text("STT")
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
                            .foregroundStyle(model.id == activeModelId ? Color.secondary : Color.red)
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.id == activeModelId)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }
}
