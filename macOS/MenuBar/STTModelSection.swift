import SwiftUI

struct STTModelSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(WhisperModelStore.self) private var whisperModelStore
    @Environment(ParakeetModelStore.self) private var parakeetModelStore
    @State private var isExpanded = false

    private var speechModels: SpeechModelCatalog {
        SpeechModelCatalog(settings: settings, whisper: whisperModelStore, parakeet: parakeetModelStore)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.stt", defaultValue: "STT Model"))
                .font(.headline)

            if !speechModels.downloadedModels.isEmpty {
                DownloadedSTTModelsList(speechModels: speechModels)
            }

            AvailableSTTModelsDisclosure(speechModels: speechModels, isExpanded: $isExpanded)

            if let error = speechModels.downloadError {
                ModelDownloadErrorView(errorMessage: error, onDismiss: speechModels.clearDownloadError)
            }
        }
        .padding()
    }
}
