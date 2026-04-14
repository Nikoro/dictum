import SwiftUI

@MainActor
struct PopoverView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var runtimeState: AppRuntimeState
    @EnvironmentObject var pipeline: DictationPipeline
    @ObservedObject private var permissionStore = SystemPermissionStore.shared

    private var isSetupComplete: Bool {
        permissionStore.allGranted && pipeline.whisperModelStore.downloadedModelIds.contains(settings.sttModelId)
    }

    var body: some View {
        Group {
            if isSetupComplete {
                mainContent
            } else if settings.hasCompletedSetup && !permissionStore.allGranted {
                PermissionsNeededView(permissionsStore: permissionStore)
            } else {
                SetupView(permissionsStore: permissionStore, whisperModelStore: pipeline.whisperModelStore)
            }
        }
        .frame(width: 360)
        .onAppear {
            permissionStore.refresh()
            if !permissionStore.allGranted {
                permissionStore.startPolling()
            }
        }
        .onChange(of: isSetupComplete) { _, complete in
            if complete {
                settings.hasCompletedSetup = true
            }
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PopoverStatusHeader()
                Divider()
                RecordingPreferencesSection()
                Divider()
                STTModelSection()
                Divider()
                STTLanguageSection()
                if settings.llmCleanupEnabled {
                    Divider()
                    LLMModelSection()
                }
                Divider()
                DownloadedModelsSection()
                Divider()
                FooterSection()
            }
        }
    }
}
