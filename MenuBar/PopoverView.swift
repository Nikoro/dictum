import SwiftUI
import AVFoundation

struct PopoverView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @StateObject private var permissions = PermissionsManager.shared

    private var isSetupComplete: Bool {
        permissions.allGranted && pipeline.whisperModelManager.downloadedModelIds.contains(settings.sttModelId)
    }

    var body: some View {
        Group {
            if isSetupComplete {
                mainContent
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
                LLMModelSection()
                Divider()
                DownloadedModelsSection()
                Divider()
                FooterSection()
            }
        }
    }
}

// MARK: - Setup / Onboarding

private struct LLMModelOption: Identifiable {
    let id: String
    let displayName: String
    let sizeGB: String
    let descriptionKey: String
    let recommended: Bool

    var description: String {
        String(localized: String.LocalizationValue(descriptionKey))
    }
}

private let llmModelOptions: [LLMModelOption] = [
    LLMModelOption(
        id: "mlx-community/Qwen3-1.7B-4bit",
        displayName: "Qwen3 1.7B",
        sizeGB: "~1.2 GB",
        descriptionKey: "llm.qwen3_1.7b.desc",
        recommended: false
    ),
    LLMModelOption(
        id: "mlx-community/Qwen3.5-4B-4bit",
        displayName: "Qwen3.5 4B",
        sizeGB: "~2.5 GB",
        descriptionKey: "llm.qwen3_4b.desc",
        recommended: true
    ),
    LLMModelOption(
        id: "mlx-community/Qwen3-8B-4bit",
        displayName: "Qwen3 8B",
        sizeGB: "~5 GB",
        descriptionKey: "llm.qwen3_8b.desc",
        recommended: false
    ),
]

private struct SetupView: View {
    @ObservedObject var permissions: PermissionsManager
    @ObservedObject var whisperManager: WhisperModelManager
    @EnvironmentObject var settings: AppSettings

    @State private var isDownloadingLLM = false
    @State private var downloadingLLMId: String?
    @State private var downloadedLLMId: String? = UserDefaults.standard.string(forKey: "llmDownloadedModelId")

    private var permissionsDone: Bool { permissions.allGranted }
    private var sttDone: Bool { whisperManager.downloadedModelIds.contains(settings.sttModelId) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.tint)
                    Text("Dictum")
                        .font(.title.bold())
                    Text(String(localized: "setup.title", defaultValue: "Setup"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                // MARK: Step 1 — Permissions
                SetupStepHeader(
                    number: 1,
                    title: String(localized: "setup.step1.title", defaultValue: "Permissions"),
                    isDone: permissionsDone
                )

                VStack(spacing: 10) {
                    PermissionRow(
                        icon: "mic.fill",
                        title: String(localized: "setup.step1.mic.title", defaultValue: "Microphone"),
                        description: String(localized: "setup.step1.mic.desc", defaultValue: "Record voice for transcription"),
                        isGranted: permissions.microphoneGranted,
                        action: {
                            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                                permissions.requestMicrophone()
                            } else {
                                permissions.openMicrophoneSettings()
                            }
                        }
                    )
                    PermissionRow(
                        icon: "hand.raised.fill",
                        title: String(localized: "setup.step1.acc.title", defaultValue: "Accessibility"),
                        description: String(localized: "setup.step1.acc.desc", defaultValue: "Global hotkey and auto-paste (Cmd+V)"),
                        isGranted: permissions.accessibilityGranted,
                        action: {
                            permissions.openAccessibilitySettings()
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // MARK: Step 2 — Model STT
                SetupStepHeader(
                    number: 2,
                    title: String(localized: "setup.step2.title", defaultValue: "Speech recognition model"),
                    isDone: sttDone
                )

                if permissionsDone {
                    VStack(spacing: 8) {
                        ForEach(WhisperModelManager.defaultModels) { model in
                            SetupModelRow(
                                model: model,
                                isSelected: settings.sttModelId == model.id,
                                isDownloaded: whisperManager.downloadedModelIds.contains(model.id),
                                isDownloading: whisperManager.downloadingModelId == model.id,
                                onSelect: {
                                    settings.sttModelId = model.id
                                    whisperManager.activeModelId = model.id
                                },
                                onDownload: {
                                    settings.sttModelId = model.id
                                    Task {
                                        try? await whisperManager.downloadAndActivate(model.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                } else {
                    Text(String(localized: "setup.step1.locked", defaultValue: "Enable permissions above first."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }

                // MARK: Step 3 — Model LLM (optional)
                SetupStepHeader(
                    number: 3,
                    title: String(localized: "setup.step3.title", defaultValue: "LLM text cleanup (optional)"),
                    isDone: downloadedLLMId != nil
                )

                if sttDone {
                    VStack(spacing: 8) {
                        ForEach(llmModelOptions) { model in
                            SetupLLMRow(
                                model: model,
                                isSelected: settings.llmModelId == model.id,
                                isDownloaded: downloadedLLMId == model.id,
                                isDownloading: downloadingLLMId == model.id,
                                onSelect: {
                                    settings.llmModelId = model.id
                                },
                                onDownload: {
                                    settings.llmModelId = model.id
                                    downloadingLLMId = model.id
                                    isDownloadingLLM = true
                                    Task {
                                        do {
                                            try await LLMProcessor.shared.loadModel(model.id)
                                            downloadedLLMId = model.id
                                            settings.llmCleanupEnabled = true
                                            UserDefaults.standard.set(model.id, forKey: "llmDownloadedModelId")
                                        } catch {
                                            dlog("[Setup] LLM download failed: \(error)")
                                        }
                                        isDownloadingLLM = false
                                        downloadingLLMId = nil
                                    }
                                }
                            )
                        }

                        Button(String(localized: "setup.step3.skip", defaultValue: "Skip \u{2014} use transcription only")) {
                            settings.llmCleanupEnabled = false
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                } else {
                    Text(String(localized: "setup.step2.locked", defaultValue: "Download STT model first."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }

                Spacer(minLength: 12)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.caption)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct SetupLLMRow: View {
    let model: LLMModelOption
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void

    var body: some View {
        Button(action: {
            if isDownloaded {
                onSelect()
            } else if !isDownloading {
                onDownload()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: isSelected && isDownloaded ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected && isDownloaded ? .green : .secondary)
                    .font(.body)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                            .font(.subheadline)
                            .fontWeight(isSelected ? .semibold : .regular)
                        if model.recommended {
                            Text(String(localized: "setup.recommended", defaultValue: "Recommended"))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.blue, in: Capsule())
                        }
                    }
                    Text(model.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(model.sizeGB)
                    .font(.caption)
                    .foregroundStyle(.orange)

                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16)
                } else if isDownloaded {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(Color.accentColor)
                        .font(.caption)
                }
            }
            .padding(10)
            .background(
                isSelected ? Color.accentColor.opacity(0.08) : Color(nsColor: .quaternarySystemFill),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Setup Helpers

private struct SetupStepHeader: View {
    let number: Int
    let title: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : Color.accentColor)
                    .frame(width: 22, height: 22)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Text(title)
                .font(.subheadline.bold())
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

private struct SetupModelRow: View {
    let model: WhisperModelInfo
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void

    private var isRecommended: Bool {
        model.id == "openai_whisper-large-v3_turbo"
    }

    var body: some View {
        Button(action: {
            if isDownloaded {
                onSelect()
            } else if !isDownloading {
                onDownload()
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)
                    .font(.body)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                            .font(.subheadline)
                            .fontWeight(isSelected ? .semibold : .regular)
                        if isRecommended {
                            Text(String(localized: "setup.recommended", defaultValue: "Recommended"))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.blue, in: Capsule())
                        }
                    }
                    Text(model.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(model.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.orange)

                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16)
                } else if isDownloaded {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(Color.accentColor)
                        .font(.caption)
                }
            }
            .padding(10)
            .background(
                isSelected ? Color.accentColor.opacity(0.08) : Color(nsColor: .quaternarySystemFill),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(isGranted ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button(String(localized: "setup.step1.enable", defaultValue: "Enable")) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Header

private struct HeaderSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
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
                .animation(.easeInOut(duration: 0.2), value: settings.appState)
            }
        }
        .padding()
    }

    private var stateDescription: String? {
        switch settings.appState {
        case .idle: return nil
        case .recording: return String(localized: "header.recording", defaultValue: "Recording...")
        case .transcribing: return String(localized: "header.transcribing", defaultValue: "Transcribing...")
        case .processingLLM: return String(localized: "header.processingLLM", defaultValue: "Cleaning text with LLM...")
        case .done: return String(localized: "header.done", defaultValue: "Done \u{2014} text pasted")
        case .error(let msg): return msg
        }
    }

    private var isProcessing: Bool {
        switch settings.appState {
        case .recording, .transcribing, .processingLLM: return true
        default: return false
        }
    }

    private var stateColor: Color {
        switch settings.appState {
        case .recording: return .red
        case .transcribing: return .yellow
        case .processingLLM: return .orange
        case .done: return .green
        case .error: return .red
        default: return .secondary
        }
    }
}

private struct StatusDot: View {
    let state: AppState

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .fill(color.opacity(isPulsing ? 0.5 : 0))
                    .frame(width: 18, height: 18)
                    .animation(isPulsing ? .easeInOut(duration: 0.6).repeatForever() : .default, value: isPulsing)
            )
    }

    private var color: Color {
        switch state {
        case .idle: return .gray
        case .recording: return .red
        case .transcribing: return .yellow
        case .processingLLM: return .orange
        case .done: return .green
        case .error: return .red
        }
    }

    private var isPulsing: Bool {
        state == .recording
    }
}

// MARK: - Prompt

private struct PromptSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.prompt", defaultValue: "LLM Prompt"))
                .font(.headline)

            TextEditor(text: $settings.llmPrompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100, maxHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary)
                .cornerRadius(8)

            Button(String(localized: "section.prompt.reset", defaultValue: "Reset to default")) {
                settings.resetPrompt()
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding()
    }
}

// MARK: - Recording Settings

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
        }
        .padding()
    }

    private var hotkeyDescription: String {
        if settings.hotkeyIsModifierOnly {
            return GlobalHotkeyManager.modifierKeyName(settings.hotkeyKeyCode) ?? "Key \(settings.hotkeyKeyCode)"
        }

        var parts: [String] = []
        let modifiers = settings.hotkeyModifiers
        if modifiers & 1048576 != 0 { parts.append("\u{2318}") }
        if modifiers & 524288 != 0 { parts.append("\u{2325}") }
        if modifiers & 262144 != 0 { parts.append("\u{2303}") }
        if modifiers & 131072 != 0 { parts.append("\u{21E7}") }

        let keyName: String
        switch settings.hotkeyKeyCode {
        case 49: keyName = "Space"
        case 36: keyName = "Return"
        case 48: keyName = "Tab"
        case 53: keyName = "Esc"
        case 51: keyName = "Delete"
        case 76: keyName = "Enter"
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

// MARK: - Hotkey Recorder

@MainActor
private final class HotkeyRecorderModel: ObservableObject {
    @Published var isRecording = false

    private var keyMonitor: Any?
    private var flagsMonitor: Any?

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true

        DictationPipeline.shared.hotkeyManager.stop()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let keyCode = Int(event.keyCode)

            if keyCode == 53 {
                self.stopRecording()
                return nil
            }

            let modifiers = Int(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue)
            self.applyHotkey(keyCode: keyCode, modifiers: modifiers, isModifierOnly: false)
            return nil
        }

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            let keyCode = Int(event.keyCode)
            guard GlobalHotkeyManager.isModifierKeyCode(keyCode) else { return event }

            let flag = GlobalHotkeyManager.modifierFlag(forKeyCode: keyCode)
            let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
            if flags.contains(flag) {
                self.applyHotkey(keyCode: keyCode, modifiers: 0, isModifierOnly: true)
                return nil
            }
            return event
        }
    }

    func stopRecording() {
        removeMonitors()
        isRecording = false
        DictationPipeline.shared.setupHotkey()
    }

    private func applyHotkey(keyCode: Int, modifiers: Int, isModifierOnly: Bool) {
        let settings = AppSettings.shared
        settings.hotkeyKeyCode = keyCode
        settings.hotkeyModifiers = modifiers
        settings.hotkeyIsModifierOnly = isModifierOnly
        stopRecording()
    }

    private func removeMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
    }
}

private struct HotkeyRecorderButton: View {
    @StateObject private var recorder = HotkeyRecorderModel()
    let hotkeyDescription: String

    var body: some View {
        Button {
            if recorder.isRecording {
                recorder.stopRecording()
            } else {
                recorder.startRecording()
            }
        } label: {
            Text(recorder.isRecording
                 ? String(localized: "section.hotkey.press", defaultValue: "Press a key...")
                 : hotkeyDescription)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(recorder.isRecording ? Color.accentColor.opacity(0.2) : Color(nsColor: .quaternaryLabelColor))
                .cornerRadius(4)
                .font(.system(.body, design: .monospaced))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(recorder.isRecording ? Color.accentColor : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private enum KeyCodeMapping {
    static func keyName(for keyCode: Int) -> String? {
        let mapping: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            50: "`",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 107: "F14",
            109: "F10", 111: "F12", 113: "F15",
            118: "F4", 119: "F2", 120: "F1",
            121: "Page Down", 122: "F16", 123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}",
        ]
        return mapping[keyCode]
    }
}

// MARK: - STT Model

private struct STTModelSection: View {
    @EnvironmentObject var pipeline: DictationPipeline
    @State private var isExpanded = false

    private var downloadedModels: [WhisperModelInfo] {
        WhisperModelManager.defaultModels.filter {
            pipeline.whisperModelManager.downloadedModelIds.contains($0.id)
        }
    }

    private var availableModels: [WhisperModelInfo] {
        WhisperModelManager.defaultModels.filter {
            !pipeline.whisperModelManager.downloadedModelIds.contains($0.id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.stt", defaultValue: "STT Model"))
                .font(.headline)

            // Downloaded models
            if !downloadedModels.isEmpty {
                VStack(spacing: 2) {
                    ForEach(downloadedModels) { model in
                        WhisperModelRow(
                            model: model,
                            isDownloaded: true,
                            isActive: pipeline.whisperModelManager.activeModelId == model.id,
                            isDownloading: false
                        ) {
                            pipeline.whisperModelManager.activeModelId = model.id
                            AppSettings.shared.sttModelId = model.id
                        }
                    }
                }
                .background(.quaternary)
                .cornerRadius(8)
            }

            // Expandable list of available models
            if !availableModels.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.accentColor)
                        Text(String(localized: "section.stt.more", defaultValue: "More models (\(availableModels.count))"))
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 2) {
                        ForEach(availableModels) { model in
                            WhisperModelRow(
                                model: model,
                                isDownloaded: false,
                                isActive: false,
                                isDownloading: pipeline.whisperModelManager.downloadingModelId == model.id
                            ) {
                                Task {
                                    try? await pipeline.whisperModelManager.downloadAndActivate(model.id)
                                }
                            }
                        }
                    }
                    .background(.quaternary)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

private struct WhisperModelRow: View {
    let model: WhisperModelInfo
    let isDownloaded: Bool
    let isActive: Bool
    let isDownloading: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                if isActive {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.caption2)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.caption2)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.displayName)
                        .fontWeight(isActive ? .semibold : .regular)
                    Text(model.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(model.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else if !isDownloaded {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - LLM Model

private struct LLMModelSection: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @ObservedObject private var browser: ModelBrowser

    @State private var isDownloading = false
    @State private var downloadingModelId: String?
    @State private var downloadError: String?

    init() {
        _browser = ObservedObject(wrappedValue: DictationPipeline.shared.modelBrowser)
    }

    private var isLLMModelDownloaded: Bool {
        pipeline.downloadedModelsManager.downloadedModels.contains { $0.id == settings.llmModelId }
    }

    private var downloadedModels: [DownloadedModel] {
        pipeline.downloadedModelsManager.downloadedModels
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.llm", defaultValue: "LLM Model"))
                .font(.headline)

            // Downloaded models list (like STT)
            if !downloadedModels.isEmpty {
                VStack(spacing: 2) {
                    ForEach(downloadedModels) { model in
                        Button {
                            settings.llmModelId = model.id
                            pipeline.downloadedModelsManager.scanDownloadedModels()
                        } label: {
                            HStack {
                                Image(systemName: model.id == settings.llmModelId ? "circle.fill" : "circle")
                                    .foregroundColor(model.id == settings.llmModelId ? .accentColor : .secondary)
                                    .font(.caption2)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(model.shortName)
                                        .fontWeight(model.id == settings.llmModelId ? .semibold : .regular)
                                    Text(model.formattedSize)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.quaternary)
                .cornerRadius(8)
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(String(localized: "section.llm.search", defaultValue: "Search models (e.g. qwen, gemma, llama)..."), text: $browser.searchQuery)
                    .textFieldStyle(.plain)
                    .onChange(of: browser.searchQuery) { _, _ in
                        browser.search()
                    }
                if browser.isSearching {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                if !browser.searchQuery.isEmpty {
                    Button {
                        browser.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary)
            .cornerRadius(8)

            // Search results
            if !browser.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(browser.searchResults) { model in
                            let isDownloaded = downloadedModels.contains { $0.id == model.id }
                            let isThisDownloading = downloadingModelId == model.id && isDownloading
                            Button {
                                guard !isDownloading else { return }
                                downloadModel(model.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(model.shortName)
                                            .font(.system(.body, design: .monospaced))
                                            .fontWeight(isDownloaded ? .semibold : .regular)
                                        if model.totalSizeBytes > 0 {
                                            Text(model.formattedSize)
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    Spacer()
                                    if isThisDownloading {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    } else if isDownloaded {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(isDownloaded || isDownloading)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(.background)
                .cornerRadius(8)
                .shadow(radius: 4)
            }

            // Download progress
            if isDownloading, let modelId = downloadingModelId {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                    Text(String(localized: "section.llm.downloading", defaultValue: "Downloading \(modelId.replacingOccurrences(of: "mlx-community/", with: ""))..."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let error = downloadError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // LLM Prompt toggle + editor
            HStack {
                Toggle("", isOn: $settings.llmCleanupEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(!isLLMModelDownloaded)
                Text(String(localized: "section.llm.prompt", defaultValue: "LLM Prompt"))
                    .font(.headline)
                    .foregroundColor(isLLMModelDownloaded ? .primary : .secondary)
            }

            if !isLLMModelDownloaded && !isDownloading {
                Text(String(localized: "section.llm.nomodel", defaultValue: "Download a model first"))
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if settings.llmCleanupEnabled && isLLMModelDownloaded {
                TextEditor(text: $settings.llmPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100, maxHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.quaternary)
                    .cornerRadius(8)

                Button(String(localized: "section.prompt.reset", defaultValue: "Reset to default")) {
                    settings.resetPrompt()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding()
        .onAppear {
            if !isLLMModelDownloaded {
                settings.llmCleanupEnabled = false
            }
        }
        .onChange(of: isLLMModelDownloaded) { _, downloaded in
            if !downloaded {
                settings.llmCleanupEnabled = false
            }
        }
    }

    private func downloadModel(_ modelId: String) {
        isDownloading = true
        downloadingModelId = modelId
        downloadError = nil
        Task {
            do {
                try await LLMProcessor.shared.loadModel(modelId)
                await MainActor.run {
                    settings.llmModelId = modelId
                    pipeline.downloadedModelsManager.scanDownloadedModels()
                    isDownloading = false
                    downloadingModelId = nil
                    browser.clearSearch()
                }
            } catch {
                await MainActor.run {
                    downloadError = error.localizedDescription
                    isDownloading = false
                    downloadingModelId = nil
                }
            }
        }
    }
}

// MARK: - Downloaded Models

private struct DownloadedModelsSection: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline

    var body: some View {
        let whisperDownloaded = WhisperModelManager.defaultModels.filter {
            pipeline.whisperModelManager.downloadedModelIds.contains($0.id)
        }
        let llmDownloaded = pipeline.downloadedModelsManager.downloadedModels
        let hasAny = !whisperDownloaded.isEmpty || !llmDownloaded.isEmpty

        if hasAny {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "section.downloaded", defaultValue: "Downloaded models"))
                    .font(.headline)

                VStack(spacing: 2) {
                    // Whisper models
                    ForEach(whisperDownloaded) { model in
                        Button {
                            pipeline.whisperModelManager.activeModelId = model.id
                            AppSettings.shared.sttModelId = model.id
                        } label: {
                            HStack {
                                Image(systemName: model.id == pipeline.whisperModelManager.activeModelId ? "circle.fill" : "circle")
                                    .foregroundColor(model.id == pipeline.whisperModelManager.activeModelId ? .accentColor : .secondary)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(model.displayName)
                                        .font(.caption)
                                    Text("STT")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(model.formattedSize)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button {
                                    pipeline.whisperModelManager.deleteModel(model.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }

                    // LLM models
                    ForEach(llmDownloaded) { model in
                        Button {
                            settings.llmModelId = model.id
                        } label: {
                            HStack {
                                Image(systemName: model.id == settings.llmModelId ? "circle.fill" : "circle")
                                    .foregroundColor(model.id == settings.llmModelId ? .accentColor : .secondary)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(model.shortName)
                                        .font(.caption)
                                    Text("LLM")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(model.formattedSize)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button {
                                    if model.id == settings.llmModelId {
                                        Task { await LLMProcessor.shared.unloadModel() }
                                    }
                                    try? pipeline.downloadedModelsManager.deleteModel(model.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.quaternary)
                .cornerRadius(8)

                let totalDisk = pipeline.downloadedModelsManager.totalSizeOnDisk + pipeline.whisperModelManager.totalSizeOnDisk()
                if totalDisk > 0 {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundColor(.secondary)
                        Text(String(localized: "section.downloaded.total", defaultValue: "Total on disk:"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: totalDisk, countStyle: .file))
                            .font(.caption.bold())
                    }
                }
            }
            .padding()
            .onAppear {
                pipeline.downloadedModelsManager.scanDownloadedModels()
            }
        }
    }
}

// MARK: - Footer

private struct FooterSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 8) {
            if case .error(let message) = settings.appState {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.caption)
        }
        .padding()
    }
}
