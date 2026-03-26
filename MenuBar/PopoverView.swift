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
                Text(hotkeyDescription)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .cornerRadius(4)
                    .font(.system(.body, design: .monospaced))
            }
        }
        .padding()
    }

    private var hotkeyDescription: String {
        var parts: [String] = []
        let modifiers = settings.hotkeyModifiers
        if modifiers & 1048576 != 0 { parts.append("⌘") } // Command
        if modifiers & 524288 != 0 { parts.append("⌥") }  // Option
        if modifiers & 262144 != 0 { parts.append("⌃") }  // Control
        if modifiers & 131072 != 0 { parts.append("⇧") }  // Shift

        let keyName: String
        switch settings.hotkeyKeyCode {
        case 49: keyName = "Space"
        case 36: keyName = "Return"
        case 48: keyName = "Tab"
        default: keyName = "Key \(settings.hotkeyKeyCode)"
        }
        parts.append(keyName)
        return parts.joined(separator: " ")
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
