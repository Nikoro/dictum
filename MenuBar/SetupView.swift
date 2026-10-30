import SwiftUI

@MainActor
struct SetupView: View {
    let permissionsStore: SystemPermissionStore
    let speechModels: SpeechModelCatalog

    @State private var downloadedLLMId: String? = UserDefaults.standard
        .string(forKey: UserDefaultsKey.llmDownloadedModelId.rawValue)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SetupHeaderView()
                SetupPermissionStep(permissionsStore: permissionsStore)
                SetupSpeechRecognitionModelStep(
                    speechModels: speechModels,
                    isUnlocked: permissionsStore.allGranted
                )
                SetupLLMProcessingStep(
                    downloadedLLMId: $downloadedLLMId,
                    isUnlocked: speechModels.hasActiveModel
                )

                Spacer(minLength: 12)
                SetupFooterView()
            }
        }
    }
}
