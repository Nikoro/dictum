import SwiftUI

@MainActor
extension View {
    func whisperModelDeletionAlert(
        model: Binding<WhisperModelInfo?>,
        onConfirmDeletion: @escaping (WhisperModelInfo) -> Void
    ) -> some View {
        modelDeletionAlert(
            title: String(localized: "alert.delete.stt.title", defaultValue: "Delete model?"),
            model: model,
            message: { modelToDelete in
                String(
                    localized: "alert.delete.stt.message",
                    defaultValue: """
                    This will remove \(modelToDelete.formattedSize) from disk. \
                    You will need to re-download the model.
                    """
                )
            },
            onConfirmDeletion: onConfirmDeletion
        )
    }

    func llmModelDeletionAlert(
        model: Binding<DownloadedLLMModel?>,
        selectedModelId: String,
        onUnloadSelectedModel: @escaping () -> Void,
        onConfirmDeletion: @escaping (DownloadedLLMModel) -> Void
    ) -> some View {
        modelDeletionAlert(
            title: String(localized: "alert.delete.llm.title", defaultValue: "Delete model?"),
            model: model,
            message: { modelToDelete in
                String(
                    localized: "alert.delete.llm.message",
                    defaultValue: """
                    This will remove \(modelToDelete.formattedSize) from disk. \
                    You will need to re-download the model.
                    """
                )
            },
            onConfirmDeletion: { modelToDelete in
                if modelToDelete.id == selectedModelId {
                    onUnloadSelectedModel()
                }
                onConfirmDeletion(modelToDelete)
            }
        )
    }

    private func modelDeletionAlert<Model>(
        title: String,
        model: Binding<Model?>,
        message: @escaping (Model) -> String,
        onConfirmDeletion: @escaping (Model) -> Void
    ) -> some View {
        alert(
            title,
            isPresented: Binding(
                get: { model.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        model.wrappedValue = nil
                    }
                }
            )
        ) {
            Button(String(localized: "alert.delete.confirm", defaultValue: "Delete"), role: .destructive) {
                if let modelToDelete = model.wrappedValue {
                    onConfirmDeletion(modelToDelete)
                }
                model.wrappedValue = nil
            }
            Button(String(localized: "alert.delete.cancel", defaultValue: "Cancel"), role: .cancel) {
                model.wrappedValue = nil
            }
        } message: {
            if let modelToDelete = model.wrappedValue {
                Text(message(modelToDelete))
            }
        }
    }
}
