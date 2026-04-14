import SwiftUI
import ServiceManagement

@MainActor
struct PopoverView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var runtimeState: AppRuntimeState
    @EnvironmentObject var pipeline: DictationPipeline
    @ObservedObject private var permissions = PermissionsManager.shared

    private var isSetupComplete: Bool {
        permissions.allGranted && pipeline.whisperModelManager.downloadedModelIds.contains(settings.sttModelId)
    }

    var body: some View {
        Group {
            if isSetupComplete {
                mainContent
            } else if settings.hasCompletedSetup && !permissions.allGranted {
                PermissionsNeededView(permissions: permissions)
            } else {
                SetupView(permissions: permissions, whisperManager: pipeline.whisperModelManager)
            }
        }
        .frame(width: 360)
        .onAppear {
            permissions.refresh()
            if !permissions.allGranted {
                permissions.startPolling()
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
                HeaderSection()
                Divider()
                RecordingSettingsSection()
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

@MainActor
private struct HeaderSection: View {
    @EnvironmentObject var runtimeState: AppRuntimeState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Spacer()
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("Dictum")
                    .font(.title2.bold())
                Spacer()
            }

            if let statusText = stateDescription {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    }
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(stateColor)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: runtimeState.appState)
            }
        }
        .padding()
    }

    private var stateDescription: String? {
        switch runtimeState.appState {
        case .idle: return nil
        case .warmingUp: return String(localized: "header.warmingUp", defaultValue: "Warming up...")
        case .recording: return String(localized: "header.recording", defaultValue: "Recording...")
        case .transcribing: return String(localized: "header.transcribing", defaultValue: "Transcribing...")
        case .processingLLM: return String(localized: "header.processingLLM", defaultValue: "Cleaning text with LLM...")
        case .done: return String(localized: "header.done", defaultValue: "Done \u{2014} text pasted")
        case .error(let msg): return msg
        }
    }

    private var isProcessing: Bool {
        switch runtimeState.appState {
        case .warmingUp, .recording, .transcribing, .processingLLM: return true
        default: return false
        }
    }

    private var stateColor: Color {
        switch runtimeState.appState {
        case .warmingUp: return .blue
        case .recording: return .red
        case .transcribing: return .yellow
        case .processingLLM: return .orange
        case .done: return .green
        case .error: return .yellow
        default: return .secondary
        }
    }
}

@MainActor
private struct LaunchAtLoginToggle: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        HStack {
            Text(String(localized: "section.launchAtLogin", defaultValue: "Launch at login"))
            Spacer()
            Toggle("", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .onChange(of: launchAtLogin) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
            .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }
}

@MainActor
private struct RecordingSettingsSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "section.mode", defaultValue: "Mode:"))
                    .font(.headline)
                Spacer()
                Picker("", selection: $settings.recordingModeRaw) {
                    ForEach(RecordingMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            HStack {
                Text(String(localized: "section.hotkey", defaultValue: "Hotkey:"))
                    .font(.headline)
                Spacer()
                HotkeyRecorderButton(hotkeyDescription: hotkeyDescription)
            }

            LaunchAtLoginToggle()

            HStack {
                Text(String(localized: "section.llm.cleanup", defaultValue: "LLM processing"))
                Spacer()
                Toggle("", isOn: $settings.llmCleanupEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
        .padding()
    }

    private var hotkeyDescription: String {
        if settings.hotkeyIsModifierOnly {
            return GlobalHotkeyManager.modifierKeyName(settings.hotkeyKeyCode) ?? "Key \(settings.hotkeyKeyCode)"
        }

        var parts: [String] = []
        let mods = NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifiers))
        if mods.contains(.command) { parts.append("\u{2318}") }
        if mods.contains(.option) { parts.append("\u{2325}") }
        if mods.contains(.control) { parts.append("\u{2303}") }
        if mods.contains(.shift) { parts.append("\u{21E7}") }

        let keyName: String
        switch settings.hotkeyKeyCode {
        case 49: keyName = String(localized: "hotkey.space", defaultValue: "Space")
        case 36: keyName = String(localized: "hotkey.return", defaultValue: "Return")
        case 48: keyName = String(localized: "hotkey.tab", defaultValue: "Tab")
        case 53: keyName = String(localized: "hotkey.esc", defaultValue: "Esc")
        case 51: keyName = String(localized: "hotkey.delete", defaultValue: "Delete")
        case 76: keyName = String(localized: "hotkey.enter", defaultValue: "Enter")
        default:
            if let scalar = KeyCodeMapping.keyName(for: settings.hotkeyKeyCode) {
                keyName = scalar
            } else {
                keyName = "Key \(settings.hotkeyKeyCode)"
            }
        }
        parts.append(keyName)
        return parts.joined(separator: " ")
    }
}
