import SwiftUI
import AVFoundation
import ServiceManagement

private let appVersion: String = appVersion

private func appIcon(forBundleId bundleId: String) -> NSImage? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
    return NSWorkspace.shared.icon(forFile: url.path)
}

private func ghostCompletionFor(_ text: String) -> String? {
    if text.hasSuffix("{{") { return "text}}" }
    return nil
}

struct PopoverView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @ObservedObject private var permissions = PermissionsManager.shared

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

    @EnvironmentObject var pipeline: DictationPipeline
    @State private var downloadedLLMId: String? = UserDefaults.standard.string(forKey: "llmDownloadedModelId")

    private var permissionsDone: Bool { permissions.allGranted }
    private var sttDone: Bool { whisperManager.downloadedModelIds.contains(settings.sttModelId) }
    private var llmDone: Bool {
        guard let id = downloadedLLMId else { return false }
        return pipeline.downloadedModelsManager.downloadedModels.contains { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image("AppLogo")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                                downloadProgress: whisperManager.downloadingModelId == model.id ? whisperManager.downloadProgress : 0,
                                onSelect: {
                                    settings.sttModelId = model.id
                                    whisperManager.activeModelId = model.id
                                },
                                onDownload: {
                                    settings.sttModelId = model.id
                                    whisperManager.downloadAndActivate(model.id)
                                },
                                onCancel: {
                                    whisperManager.cancelDownload()
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
                    title: String(localized: "setup.step3.title", defaultValue: "LLM text processing (optional)"),
                    isDone: llmDone
                )

                if sttDone {
                    VStack(spacing: 8) {
                        ForEach(llmModelOptions) { model in
                            SetupLLMRow(
                                model: model,
                                isSelected: settings.llmModelId == model.id,
                                isDownloaded: downloadedLLMId == model.id,
                                isDownloading: pipeline.llmDownloadingModelId == model.id,
                                downloadProgress: pipeline.llmDownloadingModelId == model.id ? pipeline.llmDownloadProgress : 0,
                                onSelect: {
                                    settings.llmModelId = model.id
                                },
                                onDownload: {
                                    settings.llmModelId = model.id
                                    pipeline.downloadLLMModel(model.id)
                                    // Track completion for setup step
                                    Task {
                                        // Wait for download to finish
                                        while pipeline.llmIsDownloading { try? await Task.sleep(for: .milliseconds(200)) }
                                        if pipeline.llmDownloadError == nil {
                                            downloadedLLMId = model.id
                                            settings.llmCleanupEnabled = true
                                            UserDefaults.standard.set(model.id, forKey: "llmDownloadedModelId")
                                            pipeline.warmUpModels()
                                        }
                                    }
                                },
                                onCancel: {
                                    pipeline.cancelLLMDownload()
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

                HStack {
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Image(systemName: "power")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)

                    Spacer()

                    Text("Wersja: \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Balance spacer for power button width
                    Color.clear
                        .frame(width: 16, height: 16)
                }
                .padding(.horizontal, 20)
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
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void
    var onCancel: (() -> Void)?

    var body: some View {
        Button(action: {
            if isDownloaded {
                onSelect()
            } else if !isDownloading {
                onDownload()
            }
        }) {
            VStack(spacing: 0) {
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
                                    .background(Color("AccentColor"), in: Capsule())
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
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                        Button {
                            onCancel?()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else if isDownloaded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color("AccentColor"))
                            .font(.body)
                    }
                }
                .padding(10)

                if isDownloading {
                    ProgressView(value: downloadProgress)
                        .tint(Color("AccentColor"))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
            }
            .background(
                isSelected ? Color("AccentColor").opacity(0.08) : Color(nsColor: .quaternarySystemFill),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color("AccentColor").opacity(0.3) : .clear, lineWidth: 1)
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
                    .fill(isDone ? Color.green : Color("AccentColor"))
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
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void
    var onCancel: (() -> Void)?

    private var isRecommended: Bool { model.isRecommended }

    var body: some View {
        Button(action: {
            if isDownloaded {
                onSelect()
            } else if !isDownloading {
                onDownload()
            }
        }) {
            VStack(spacing: 0) {
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
                                    .background(Color("AccentColor"), in: Capsule())
                            }
                        }
                        if !isDownloading {
                            Text(model.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text(model.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.orange)

                    if isDownloading {
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    } else if isDownloaded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color("AccentColor"))
                            .font(.body)
                    }
                }
                .padding(10)

                if isDownloading {
                    ProgressView(value: downloadProgress)
                        .tint(Color("AccentColor"))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
            }
            .background(
                isSelected ? Color("AccentColor").opacity(0.08) : Color(nsColor: .quaternarySystemFill),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color("AccentColor").opacity(0.3) : .clear, lineWidth: 1)
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
                .animation(.easeInOut(duration: 0.2), value: settings.appState)
            }
        }
        .padding()
    }

    private var stateDescription: String? {
        switch settings.appState {
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
        switch settings.appState {
        case .warmingUp, .recording, .transcribing, .processingLLM: return true
        default: return false
        }
    }

    private var stateColor: Color {
        switch settings.appState {
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

// MARK: - Launch at Login

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
        // Re-register hotkey if we were recording when dismissed
        Task { @MainActor in
            DictationPipeline.shared.setupHotkey()
        }
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
                .background(recorder.isRecording ? Color("AccentColor").opacity(0.2) : Color(nsColor: .quaternaryLabelColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .font(.system(.body, design: .monospaced))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(recorder.isRecording ? Color("AccentColor") : .clear, lineWidth: 1)
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
    @EnvironmentObject var settings: AppSettings
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
                            isDownloading: false,
                            downloadProgress: 0
                        ) {
                            pipeline.whisperModelManager.activeModelId = model.id
                            settings.sttModelId = model.id
                        }
                    }
                }
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
                            .foregroundStyle(Color("AccentColor"))
                        Text(String(localized: "section.stt.more", defaultValue: "More models (\(availableModels.count))"))
                            .font(.subheadline)
                            .foregroundStyle(Color("AccentColor"))
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                                isDownloading: pipeline.whisperModelManager.downloadingModelId == model.id,
                                downloadProgress: pipeline.whisperModelManager.downloadingModelId == model.id ? pipeline.whisperModelManager.downloadProgress : 0
                            ) {
                                pipeline.whisperModelManager.downloadAndActivate(model.id)
                            } onCancel: {
                                pipeline.whisperModelManager.cancelDownload()
                            }
                        }
                    }
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
    let downloadProgress: Double
    let onSelect: () -> Void
    var onCancel: (() -> Void)?

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                HStack {
                    if isActive {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(Color("AccentColor"))
                            .font(.caption2)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                            .font(.caption2)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.displayName)
                            .fontWeight(isActive ? .semibold : .regular)
                        Text(model.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(model.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isDownloading {
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                        Button {
                            onCancel?()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else if !isDownloaded {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color("AccentColor"))
                            .font(.body)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                if isDownloading {
                    ProgressView(value: downloadProgress)
                        .tint(Color("AccentColor"))
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - STT Language

private struct STTLanguageSection: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showingAppPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.stt.language", defaultValue: "Język rozpoznawania"))
                .font(.headline)

            // General language picker
            HStack {
                Text(String(localized: "section.stt.language.general", defaultValue: "Ogólny"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { settings.sttLanguage },
                    set: { settings.sttLanguage = $0 }
                )) {
                    ForEach(STTLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }

            // Per-app languages
            HStack {
                Text(String(localized: "section.stt.language.perapp", defaultValue: "Język per aplikacja"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingAppPicker = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.body)
                }
                .buttonStyle(.plain)
            }

            if settings.appSTTLanguages.isEmpty {
                Text(String(localized: "section.stt.language.perapp.empty", defaultValue: "Brak — używany będzie język ogólny"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(settings.appSTTLanguages) { appLang in
                AppSTTLanguageRow(appLang: appLang)
            }
        }
        .padding()
        .sheet(isPresented: $showingAppPicker) {
            InstalledAppPickerSheet(
                title: String(localized: "section.stt.language.picker.title", defaultValue: "Wybierz aplikację"),
                excludedBundleIds: Set(settings.appSTTLanguages.map(\.bundleId))
            ) { bundleId, appName in
                settings.addAppSTTLanguage(AppSTTLanguage(
                    bundleId: bundleId,
                    appName: appName,
                    language: .auto
                ))
            }
        }
    }
}

private struct AppSTTLanguageRow: View {
    let appLang: AppSTTLanguage
    @EnvironmentObject var settings: AppSettings

    private var cleanAppName: String {
        appLang.appName.replacingOccurrences(of: ".app", with: "")
    }

    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: Binding(
                get: { appLang.enabled },
                set: { _ in settings.toggleAppSTTLanguage(bundleId: appLang.bundleId) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)

            if let icon = appIcon(forBundleId: appLang.bundleId) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "app.fill")
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.secondary)
            }
            Text(cleanAppName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(appLang.enabled ? .primary : .secondary)

            Spacer()

            Picker("", selection: Binding(
                get: { appLang.language },
                set: { settings.updateAppSTTLanguage(bundleId: appLang.bundleId, language: $0) }
            )) {
                ForEach(STTLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .labelsHidden()
            .frame(width: 130)
            .controlSize(.small)

            Button {
                settings.removeAppSTTLanguage(bundleId: appLang.bundleId)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct InstalledAppPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let excludedBundleIds: Set<String>
    let onSelect: (_ bundleId: String, _ appName: String) -> Void

    @State private var searchText = ""
    @State private var apps: [(name: String, bundleId: String, icon: NSImage)] = []
    @State private var isLoading = true

    private var filteredApps: [(name: String, bundleId: String, icon: NSImage)] {
        let available = apps.filter { !excludedBundleIds.contains($0.bundleId) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "picker.search", defaultValue: "Szukaj aplikacji..."), text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if filteredApps.isEmpty {
                Text(searchText.isEmpty
                    ? String(localized: "picker.empty", defaultValue: "No apps found")
                    : String(localized: "picker.noResults", defaultValue: "No results"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredApps, id: \.bundleId) { app in
                            Button {
                                onSelect(app.bundleId, app.name)
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(nsImage: app.icon)
                                        .resizable()
                                        .interpolation(.high)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                    Text(app.name)
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 320, height: 400)
        .task { await loadInstalledApps() }
    }

    private func loadInstalledApps() async {
        let found: [(name: String, bundleId: String, icon: NSImage)] = await Task.detached {
            let workspace = NSWorkspace.shared
            let appURLs = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
                + FileManager.default.urls(for: .applicationDirectory, in: .systemDomainMask)

            var result: [(name: String, bundleId: String, icon: NSImage)] = []
            var seen = Set<String>()

            for dir in appURLs {
                guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
                for url in contents where url.pathExtension == "app" {
                    guard let bundle = Bundle(url: url),
                          let bundleId = bundle.bundleIdentifier,
                          !seen.contains(bundleId) else { continue }
                    seen.insert(bundleId)
                    let name = FileManager.default.displayName(atPath: url.path)
                    let icon = workspace.icon(forFile: url.path)
                    icon.size = NSSize(width: 24, height: 24)
                    result.append((name: name, bundleId: bundleId, icon: icon))
                }
            }

            let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            if let contents = try? FileManager.default.contentsOfDirectory(at: userApps, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "app" {
                    guard let bundle = Bundle(url: url),
                          let bundleId = bundle.bundleIdentifier,
                          !seen.contains(bundleId) else { continue }
                    seen.insert(bundleId)
                    let name = FileManager.default.displayName(atPath: url.path)
                    let icon = workspace.icon(forFile: url.path)
                    icon.size = NSSize(width: 24, height: 24)
                    result.append((name: name, bundleId: bundleId, icon: icon))
                }
            }

            return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value

        apps = found
        isLoading = false
    }
}

// MARK: - LLM Model

private struct LLMModelSection: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @ObservedObject private var browser: ModelBrowser

    init() {
        _browser = ObservedObject(wrappedValue: ModelBrowser.shared)
    }

    private var isDownloading: Bool { pipeline.llmIsDownloading }
    private var downloadingModelId: String? { pipeline.llmDownloadingModelId }
    private var downloadProgress: Double { pipeline.llmDownloadProgress }

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
                                    .foregroundStyle(model.id == settings.llmModelId ? Color("AccentColor") : .secondary)
                                    .font(.caption2)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(model.shortName)
                                        .fontWeight(model.id == settings.llmModelId ? .semibold : .regular)
                                    Text(model.formattedSize)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
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
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

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
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    Spacer()
                                    if isThisDownloading {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    } else if isDownloaded {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(isDownloaded || isThisDownloading)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
            }

            // Download progress
            if isDownloading, let modelId = downloadingModelId {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text(String(localized: "section.llm.downloading", defaultValue: "Downloading \(modelId.replacingOccurrences(of: "mlx-community/", with: ""))..."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Button {
                            cancelDownload()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    ProgressView(value: downloadProgress)
                        .tint(Color("AccentColor"))
                }
            }

            if let error = pipeline.llmDownloadError {
                HStack {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button {
                        pipeline.llmDownloadError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Prompts
            GeneralPromptSection()
            AppPromptsSection()
        }
        .padding()
    }

    private func downloadModel(_ modelId: String) {
        browser.clearSearch()
        pipeline.downloadLLMModel(modelId)
    }

    private func cancelDownload() {
        pipeline.cancelLLMDownload()
    }
}

// MARK: - Per-App Prompts

// MARK: - General Prompt

private struct GeneralPromptSection: View {
    @EnvironmentObject var settings: AppSettings
    @State private var localPrompt: String = ""

    private var ghostSuffix: String? { ghostCompletionFor(localPrompt) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Toggle("", isOn: $settings.llmGeneralPromptEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.mini)

                Image(systemName: "text.bubble")
                    .frame(width: 18, height: 18)
                    .foregroundStyle(settings.llmGeneralPromptEnabled ? .primary : .secondary)

                Text(String(localized: "section.prompt.general", defaultValue: "Prompt ogólny"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(settings.llmGeneralPromptEnabled ? .primary : .secondary)
            }

            if settings.llmGeneralPromptEnabled {
                PromptTextEditor(
                    text: $localPrompt,
                    ghostSuffix: ghostSuffix,
                    placeholder: String(localized: "section.prompt.general.placeholder", defaultValue: "Wpisz prompt ogólny..."),
                    onTab: { acceptGhost() }
                )
                .frame(minHeight: 80, maxHeight: 120)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: localPrompt) { _, newValue in
                    settings.llmPrompt = newValue
                }

                Button(String(localized: "section.prompt.example", defaultValue: "Przykładowy prompt")) {
                    let example = "Usuń wypełniacze (yyy, eee, hmm). Popraw interpunkcję i literówki. Popraw zdania, które nie mają sensu. Nie zmieniaj stylu. Zwróć tylko poprawiony tekst."
                    localPrompt = example
                    settings.llmPrompt = example
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(Color("AccentColor"))
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { localPrompt = settings.llmPrompt }
    }

    private func acceptGhost() {
        guard let ghost = ghostSuffix else { return }
        localPrompt += ghost
    }
}

private struct AppPromptsSection: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showingAppPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "section.prompt.perapp", defaultValue: "Prompty per aplikacja"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingAppPicker = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.body)
                }
                .buttonStyle(.plain)
            }

            if settings.appPrompts.isEmpty {
                Text(String(localized: "section.prompt.perapp.empty", defaultValue: "Brak — używany będzie prompt ogólny"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(settings.appPrompts) { appPrompt in
                AppPromptRow(appPrompt: appPrompt)
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            InstalledAppPickerSheet(
                title: String(localized: "section.prompt.picker.title", defaultValue: "Wybierz aplikację"),
                excludedBundleIds: Set(settings.appPrompts.map(\.bundleId))
            ) { bundleId, appName in
                settings.addAppPrompt(AppPrompt(
                    bundleId: bundleId,
                    appName: appName,
                    prompt: ""
                ))
            }
        }
    }
}

private struct AppPromptRow: View {
    let appPrompt: AppPrompt
    @EnvironmentObject var settings: AppSettings
    @State private var localPrompt: String = ""

    /// Ghost text suggestion — shows greyed-out completion after `{{`
    private var ghostSuffix: String? { ghostCompletionFor(localPrompt) }

    private var cleanAppName: String {
        appPrompt.appName.replacingOccurrences(of: ".app", with: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Toggle("", isOn: Binding(
                    get: { appPrompt.enabled },
                    set: { _ in settings.toggleAppPrompt(bundleId: appPrompt.bundleId) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)

                if let icon = appIcon(forBundleId: appPrompt.bundleId) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "app.fill")
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.secondary)
                }
                Text(cleanAppName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(appPrompt.enabled ? .primary : .secondary)
                Spacer()
                Button {
                    settings.removeAppPrompt(bundleId: appPrompt.bundleId)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            if appPrompt.enabled {
                PromptTextEditor(
                    text: $localPrompt,
                    ghostSuffix: ghostSuffix,
                    placeholder: String(localized: String.LocalizationValue("section.prompt.perapp.placeholder \(cleanAppName)")),
                    onTab: { acceptGhost() }
                )
                .frame(minHeight: 60, maxHeight: 100)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: localPrompt) { _, newValue in
                    settings.updateAppPrompt(bundleId: appPrompt.bundleId, prompt: newValue)
                }
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { localPrompt = appPrompt.prompt }
    }

    private func acceptGhost() {
        guard let ghost = ghostSuffix else { return }
        // Append ghost completion (e.g. "text}}" after "{{")
        localPrompt += ghost
    }
}

// MARK: - GhostTextView (NSTextView subclass)

/// NSTextView that draws placeholder when empty and ghost completion after `{{`
private class GhostTextView: NSTextView {
    var placeholder: String = ""
    var ghostSuffix: String? {
        didSet { needsDisplay = true }
    }

    private let ghostColor = NSColor.secondaryLabelColor.withAlphaComponent(0.4)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw placeholder when empty — aligned with insertion point
        if string.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: ghostColor
            ]
            let origin = textContainerOrigin
            let inset = textContainer?.lineFragmentPadding ?? 0
            let point = NSPoint(x: origin.x + inset, y: origin.y)
            (placeholder as NSString).draw(at: point, withAttributes: attrs)
        }

        // Draw ghost suffix inline after last character
        if let ghost = ghostSuffix, !string.isEmpty, let lm = layoutManager, let tc = textContainer {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: ghostColor
            ]
            let glyphIndex = lm.glyphIndexForCharacter(at: (string as NSString).length - 1)
            var lineRect = lm.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let locInLine = lm.location(forGlyphAt: glyphIndex)
            let charSize = (String(string.last!) as NSString).size(withAttributes: [
                .font: font ?? NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            ])
            let x = lineRect.origin.x + locInLine.x + charSize.width + textContainerInset.width
            let y = lineRect.origin.y + textContainerInset.height
            (ghost as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
        }
    }
}

/// SwiftUI wrapper for GhostTextView
private struct PromptTextEditor: NSViewRepresentable {
    @Binding var text: String
    let ghostSuffix: String?
    let placeholder: String
    let onTab: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = GhostTextView()
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.placeholder = placeholder
        textView.ghostSuffix = ghostSuffix
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? GhostTextView else { return }
        let coord = context.coordinator

        textView.placeholder = placeholder
        textView.ghostSuffix = ghostSuffix
        coord.ghostSuffix = ghostSuffix
        coord.onTab = onTab

        // Sync binding → NSTextView when text changed externally
        if textView.string != text {
            textView.string = text
            textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            textView.needsDisplay = true
        }

        if coord.didAcceptGhost {
            coord.didAcceptGhost = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onTab: onTab, ghostSuffix: ghostSuffix)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onTab: () -> Void
        var ghostSuffix: String?
        var didAcceptGhost = false
        weak var textView: GhostTextView?

        init(text: Binding<String>, onTab: @escaping () -> Void, ghostSuffix: String?) {
            self.text = text
            self.onTab = onTab
            self.ghostSuffix = ghostSuffix
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            textView.needsDisplay = true
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)), ghostSuffix != nil {
                didAcceptGhost = true
                onTab()
                return true
            }
            return false
        }
    }
}


// MARK: - Downloaded Models

private struct DownloadedModelsSection: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline
    @State private var modelToDeleteSTT: WhisperModelInfo?
    @State private var modelToDeleteLLM: DownloadedModel?

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
                            settings.sttModelId = model.id
                        } label: {
                            HStack {
                                Image(systemName: model.id == pipeline.whisperModelManager.activeModelId ? "circle.fill" : "circle")
                                    .foregroundStyle(model.id == pipeline.whisperModelManager.activeModelId ? Color("AccentColor") : .secondary)
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
                                    modelToDeleteSTT = model
                                } label: {
                                    let isActive = model.id == pipeline.whisperModelManager.activeModelId
                                    Image(systemName: "trash")
                                        .foregroundStyle(isActive ? Color.secondary : Color.red)
                                        .font(.body)
                                }
                                .buttonStyle(.plain)
                                .disabled(model.id == pipeline.whisperModelManager.activeModelId)
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
                                    .foregroundStyle(model.id == settings.llmModelId ? Color("AccentColor") : .secondary)
                                    .font(.caption)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(model.shortName)
                                        .font(.caption)
                                    Text("LLM")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(model.formattedSize)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    modelToDeleteLLM = model
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                        .font(.body)
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
                .clipShape(RoundedRectangle(cornerRadius: 8))

                let totalDisk = pipeline.downloadedModelsManager.totalSizeOnDisk + pipeline.whisperModelManager.totalSizeOnDisk()
                if totalDisk > 0 {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundStyle(.secondary)
                        Text(String(localized: "section.downloaded.total", defaultValue: "Total on disk:"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            .alert(
                String(localized: "alert.delete.stt.title", defaultValue: "Delete model?"),
                isPresented: Binding(get: { modelToDeleteSTT != nil }, set: { if !$0 { modelToDeleteSTT = nil } })
            ) {
                Button(String(localized: "alert.delete.confirm", defaultValue: "Delete"), role: .destructive) {
                    if let model = modelToDeleteSTT {
                        pipeline.whisperModelManager.deleteModel(model.id)
                    }
                    modelToDeleteSTT = nil
                }
                Button(String(localized: "alert.delete.cancel", defaultValue: "Cancel"), role: .cancel) {
                    modelToDeleteSTT = nil
                }
            } message: {
                if let model = modelToDeleteSTT {
                    Text(String(localized: "alert.delete.stt.message", defaultValue: "This will remove \(model.formattedSize) from disk. You will need to re-download the model."))
                }
            }
            .alert(
                String(localized: "alert.delete.llm.title", defaultValue: "Delete model?"),
                isPresented: Binding(get: { modelToDeleteLLM != nil }, set: { if !$0 { modelToDeleteLLM = nil } })
            ) {
                Button(String(localized: "alert.delete.confirm", defaultValue: "Delete"), role: .destructive) {
                    if let model = modelToDeleteLLM {
                        if model.id == settings.llmModelId {
                            Task { await LLMProcessor.shared.unloadModel() }
                        }
                        try? pipeline.downloadedModelsManager.deleteModel(model.id)
                    }
                    modelToDeleteLLM = nil
                }
                Button(String(localized: "alert.delete.cancel", defaultValue: "Cancel"), role: .cancel) {
                    modelToDeleteLLM = nil
                }
            } message: {
                if let model = modelToDeleteLLM {
                    Text(String(localized: "alert.delete.llm.message", defaultValue: "This will remove \(model.formattedSize) from disk. You will need to re-download the model."))
                }
            }
        }
    }
}

// MARK: - Footer

private struct FooterSection: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var updaterManager: UpdaterManager
    @State private var showUninstallAlert = false

    var body: some View {
        VStack(spacing: 8) {
            if case .error(let message) = settings.appState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            HStack {
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)

                Spacer()

                Button(action: { updaterManager.checkForUpdates() }) {
                    Text("Wersja: \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(updaterManager.canCheckForUpdates ? Color("AccentColor") : .secondary)
                        .underline(updaterManager.canCheckForUpdates)
                }
                .buttonStyle(.plain)
                .disabled(!updaterManager.canCheckForUpdates)
                .help(String(localized: "footer.checkUpdates", defaultValue: "Sprawdź aktualizacje"))

                Spacer()

                Button(action: { showUninstallAlert = true }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
        }
        .padding()
        .alert(
            String(localized: "uninstall.title", defaultValue: "Uninstall Dictum?"),
            isPresented: $showUninstallAlert
        ) {
            Button(String(localized: "uninstall.cancel", defaultValue: "Cancel"), role: .cancel) {}
            Button(String(localized: "uninstall.confirm", defaultValue: "Uninstall"), role: .destructive) {
                performUninstall()
            }
        } message: {
            Text(String(localized: "uninstall.message", defaultValue: "This will delete all downloaded models, settings, and move Dictum to Trash. This cannot be undone."))
        }
    }

    private func performUninstall() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // 1. Delete LLM models (~/Library/Caches/models/)
        let mlxCacheDir = home.appendingPathComponent("Library/Caches/models")
        try? fm.removeItem(at: mlxCacheDir)

        // 2. Delete app cache (~/Library/Caches/com.dominikkrajcer.dictum/)
        let appCacheDir = home.appendingPathComponent("Library/Caches/com.dominikkrajcer.dictum")
        try? fm.removeItem(at: appCacheDir)

        // 3. Delete log file
        let logDir = home.appendingPathComponent("Library/Logs/Dictum")
        try? fm.removeItem(at: logDir)

        // 4. Clear UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }

        // 5. Move app to Trash
        if let appURL = Bundle.main.bundleURL as URL? {
            try? fm.trashItem(at: appURL, resultingItemURL: nil)
        }

        // 6. Quit
        NSApplication.shared.terminate(nil)
    }
}
