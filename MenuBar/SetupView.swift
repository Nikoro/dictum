import SwiftUI

@MainActor
struct SetupView: View {
    @ObservedObject var permissionsStore: SystemPermissionStore
    @ObservedObject var whisperModelStore: WhisperModelStore
    @EnvironmentObject var settings: AppSettings

    @EnvironmentObject var pipeline: DictationPipeline
    @State private var downloadedLLMId: String? = UserDefaults.standard.string(forKey: UserDefaultsKey.llmDownloadedModelId.rawValue)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SetupHeaderView()
                SetupPermissionStep(permissionsStore: permissionsStore)
                SetupSpeechRecognitionModelStep(
                    whisperModelStore: whisperModelStore,
                    selectedModelId: $settings.sttModelId,
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
