import SwiftUI
import ServiceManagement

let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

func appIcon(forBundleId bundleId: String) -> NSImage? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
    return NSWorkspace.shared.icon(forFile: url.path)
}

func ghostCompletionFor(_ text: String) -> String? {
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
