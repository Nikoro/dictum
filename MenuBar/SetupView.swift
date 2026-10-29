import SwiftUI

@MainActor
struct SetupView: View {
    let permissionsStore: SystemPermissionStore
    let whisperModelStore: WhisperModelStore
    @Environment(AppSettings.self) private var settings

    @State private var downloadedLLMId: String? = UserDefaults.standard
        .string(forKey: UserDefaultsKey.llmDownloadedModelId.rawValue)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SetupHeaderView()
                SetupPermissionStep(permissionsStore: permissionsStore)
                SetupSpeechRecognitionModelStep(
                    whisperModelStore: whisperModelStore,
                    selectedModelId: Bindable(settings).sttModelId,
                    isUnlocked: permissionsStore.allGranted
                )
                SetupLLMProcessingStep(
                    downloadedLLMId: $downloadedLLMId,
                    isUnlocked: whisperModelStore.downloadedModelIds.contains(settings.sttModelId)
                )

                Spacer(minLength: 12)
                SetupFooterView()
            }
        }
    }
}
