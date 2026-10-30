import SwiftUI

@MainActor
struct PopoverView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(WhisperModelStore.self) private var whisperModelStore
    @Environment(SystemPermissionStore.self) private var permissionStore

    private var isSetupComplete: Bool {
        permissionStore.allGranted && whisperModelStore.downloadedModelIds.contains(settings.sttModelId)
    }

    var body: some View {
        Group {
            if isSetupComplete {
                mainContent
            } else if settings.hasCompletedSetup, !permissionStore.allGranted {
                PermissionsNeededView(permissionsStore: permissionStore)
            } else {
                SetupView(permissionsStore: permissionStore, whisperModelStore: whisperModelStore)
            }
        }
        .frame(width: 360)
        .onAppear {
            permissionStore.refresh()
            if !permissionStore.allGranted {
                permissionStore.startPolling()
            }
        }
        .onDisappear {
            permissionStore.stopPolling()
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
                AudioPreferencesSection()
                if settings.llmCleanupEnabled {
                    UnifiedPromptSection()
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                Divider()
                STTModelSection()
                Divider()
                STTLanguageSection()
                Divider()
                DictionarySection()
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
