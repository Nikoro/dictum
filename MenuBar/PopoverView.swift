import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HeaderSection()
                Divider()
                PromptSection()
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
        .frame(width: 360)
    }
}

// MARK: - Header

private struct HeaderSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Dictum")
                .font(.title2.bold())
            Spacer()
            StatusDot(state: settings.appState)
        }
        .padding()
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
            Text("Prompt LLM")
                .font(.headline)

            TextEditor(text: $settings.llmPrompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100, maxHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary)
                .cornerRadius(8)

            Button("Przywróć domyślny") {
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
    @State private var isRecordingHotkey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tryb:")
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
                Text("Hotkey:")
                    .font(.headline)
                Spacer()
                HotkeyRecorderButton(
                    isRecording: $isRecordingHotkey,
                    hotkeyDescription: hotkeyDescription
                )
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
        if modifiers & 1048576 != 0 { parts.append("⌘") }
        if modifiers & 524288 != 0 { parts.append("⌥") }
        if modifiers & 262144 != 0 { parts.append("⌃") }
        if modifiers & 131072 != 0 { parts.append("⇧") }

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

private struct HotkeyRecorderButton: View {
    @Binding var isRecording: Bool
    let hotkeyDescription: String

    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            Text(isRecording ? "Naciśnij klawisz..." : hotkeyDescription)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isRecording ? Color.accentColor.opacity(0.2) : Color(nsColor: .quaternaryLabelColor))
                .cornerRadius(4)
                .font(.system(.body, design: .monospaced))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isRecording ? Color.accentColor : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .background(
            isRecording ? HotkeyRecorderEventView(isRecording: $isRecording) : nil
        )
    }
}

/// NSView that installs a local event monitor to capture the next key for hotkey assignment.
private struct HotkeyRecorderEventView: NSViewRepresentable {
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> NSView {
        let view = HotkeyCapturingNSView()
        view.onCapture = { keyCode, modifiers, isModifierOnly in
            let settings = AppSettings.shared
            settings.hotkeyKeyCode = keyCode
            settings.hotkeyModifiers = modifiers
            settings.hotkeyIsModifierOnly = isModifierOnly

            // Restart hotkey listener with new settings
            DictationPipeline.shared.hotkeyManager.stop()
            DictationPipeline.shared.setupHotkey()

            DispatchQueue.main.async {
                isRecording = false
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class HotkeyCapturingNSView: NSView {
    var onCapture: ((Int, Int, Bool) -> Void)?
    private var keyMonitor: Any?
    private var flagsMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }

        // Monitor for regular keys (key + modifiers combo)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let keyCode = Int(event.keyCode)
            let modifiers = Int(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue)
            self.onCapture?(keyCode, modifiers, false)
            self.removeMonitors()
            return nil // consume
        }

        // Monitor for modifier-only keys (e.g. Right Command)
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            let keyCode = Int(event.keyCode)
            guard GlobalHotkeyManager.isModifierKeyCode(keyCode) else { return event }
            // Only capture on press (flag going up), not release
            let flag = GlobalHotkeyManager.modifierFlag(forKeyCode: keyCode)
            let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
            if flags.contains(flag) {
                self.onCapture?(keyCode, 0, true)
                self.removeMonitors()
                return nil
            }
            return event
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            removeMonitors()
        }
        super.viewWillMove(toWindow: newWindow)
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
}

/// Maps common key codes to human-readable names.
private enum KeyCodeMapping {
    static func keyName(for keyCode: Int) -> String? {
        // Map of common key codes to display characters
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
            121: "Page Down", 122: "F16", 123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return mapping[keyCode]
    }
}

// MARK: - STT Model

private struct STTModelSection: View {
    @EnvironmentObject var pipeline: DictationPipeline

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model STT")
                .font(.headline)

            VStack(spacing: 2) {
                ForEach(WhisperModelManager.defaultModels) { model in
                    WhisperModelRow(
                        model: model,
                        isDownloaded: pipeline.whisperModelManager.downloadedModelIds.contains(model.id),
                        isActive: pipeline.whisperModelManager.activeModelId == model.id,
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
                    .foregroundColor(.orange)

                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else if isDownloaded {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
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

    init() {
        _browser = ObservedObject(wrappedValue: DictationPipeline.shared.modelBrowser)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model LLM")
                .font(.headline)

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Szukaj modeli (np. qwen, gemma, llama)...", text: $browser.searchQuery)
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
                            ModelResultRow(
                                model: model,
                                isActive: model.id == settings.llmModelId
                            ) {
                                Task {
                                    settings.llmModelId = model.id
                                    try? await LLMProcessor.shared.loadModel(model.id)
                                    pipeline.downloadedModelsManager.scanDownloadedModels()
                                }
                                browser.clearSearch()
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(.background)
                .cornerRadius(8)
                .shadow(radius: 4)
            }

            // Active model + LLM toggle
            HStack {
                Text("Aktywny:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(settings.llmModelId.replacingOccurrences(of: "mlx-community/", with: ""))
                    .font(.system(.subheadline, design: .monospaced))
                    .lineLimit(1)
            }

            Toggle("LLM cleanup", isOn: $settings.llmCleanupEnabled)
                .toggleStyle(.switch)
                .font(.subheadline)
        }
        .padding()
    }
}

private struct ModelResultRow: View {
    let model: HFModelInfo
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.shortName)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(isActive ? .bold : .regular)
                    HStack(spacing: 8) {
                        if model.totalSizeBytes > 0 {
                            Label(model.formattedSize, systemImage: "internaldrive")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        if let downloads = model.downloads {
                            Label(formatDownloads(downloads), systemImage: "arrow.down.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func formatDownloads(_ n: Int) -> String {
        if n >= 1_000_000 { return "\(n / 1_000_000)M" }
        if n >= 1_000 { return "\(n / 1_000)k" }
        return "\(n)"
    }
}

// MARK: - Downloaded Models

private struct DownloadedModelsSection: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pipeline: DictationPipeline

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // LLM models
            let llmModels = pipeline.downloadedModelsManager.downloadedModels
            if !llmModels.isEmpty {
                HStack {
                    Text("Pobrane modele LLM:")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(pipeline.downloadedModelsManager.formattedTotalSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ForEach(llmModels) { model in
                    HStack {
                        Image(systemName: model.id == settings.llmModelId ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(model.id == settings.llmModelId ? .green : .secondary)
                            .font(.caption)
                        Text(model.shortName)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(model.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button {
                            try? pipeline.downloadedModelsManager.deleteModel(model.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Whisper models
            let whisperDownloaded = pipeline.whisperModelManager.downloadedModelIds
            if !whisperDownloaded.isEmpty {
                HStack {
                    Text("Pobrane modele Whisper:")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(ByteCountFormatter.string(
                        fromByteCount: pipeline.whisperModelManager.totalSizeOnDisk(),
                        countStyle: .file
                    ))
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                ForEach(WhisperModelManager.defaultModels.filter { whisperDownloaded.contains($0.id) }) { model in
                    HStack {
                        Image(systemName: model.id == pipeline.whisperModelManager.activeModelId ? "circle.fill" : "circle")
                            .foregroundColor(model.id == pipeline.whisperModelManager.activeModelId ? .accentColor : .secondary)
                            .font(.caption)
                        Text(model.displayName)
                            .font(.caption)
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
                }
            }

            // Total disk usage
            let totalDisk = pipeline.downloadedModelsManager.totalSizeOnDisk + pipeline.whisperModelManager.totalSizeOnDisk()
            if totalDisk > 0 {
                Divider()
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.secondary)
                    Text("Łącznie na dysku:")
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
            pipeline.whisperModelManager.scanDownloaded()
        }
    }
}

// MARK: - Footer

private struct FooterSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 8) {
            // Status text
            if case .error(let message) = settings.appState {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }

            // Accessibility warning
            if !AXIsProcessTrusted() {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("Brak uprawnień Accessibility")
                        .font(.caption)
                    Spacer()
                    Button("Otwórz Ustawienia") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        NSWorkspace.shared.open(url)
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
                .padding(8)
                .background(.yellow.opacity(0.1))
                .cornerRadius(6)
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
