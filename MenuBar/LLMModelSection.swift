import SwiftUI

struct LLMModelSection: View {
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
                                        HStack(spacing: 6) {
                                            Text(model.shortName)
                                                .font(.system(.body, design: .monospaced))
                                                .fontWeight(isDownloaded ? .semibold : .regular)
                                            if model.isRecommended {
                                                Text(String(localized: "setup.recommended", defaultValue: "Recommended"))
                                                    .font(.system(size: 9, weight: .semibold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(Color("AccentColor"), in: Capsule())
                                            }
                                        }
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
            InstructionsSection(hasDownloadedModels: !downloadedModels.isEmpty)
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

// MARK: - Unified System Prompt

struct UnifiedPromptSection: View {
    @EnvironmentObject var settings: AppSettings
    @State private var localPrompt: String = ""
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header — always visible, acts as toggle
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .frame(width: 18, height: 18)

                Text(String(localized: "section.prompt.unified", defaultValue: "System prompt"))
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Expanded content
            if isExpanded {
                HStack {
                    Spacer()
                    Button(String(localized: "section.prompt.unified.reset", defaultValue: "Reset")) {
                        settings.resetUnifiedPrompt()
                        localPrompt = settings.unifiedSystemPrompt
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(Color("AccentColor"))
                }

                PromptTextEditor(
                    text: $localPrompt,
                    placeholder: String(AppSettings.defaultUnifiedPrompt.prefix(100)) + "..."
                )
                .frame(minHeight: 100, maxHeight: 160)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: localPrompt) { _, newValue in
                    settings.unifiedSystemPrompt = newValue
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .onAppear {
            localPrompt = settings.unifiedSystemPrompt.isEmpty
                ? AppSettings.defaultUnifiedPrompt
                : settings.unifiedSystemPrompt
        }
    }
}

// MARK: - Instructions (All Apps + Per-App)

private struct InstructionsSection: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showingAppPicker = false
    let hasDownloadedModels: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.instructions", defaultValue: "Instructions"))
                .font(.headline)

            // "All apps" — the default/fallback prompt
            AllAppsPromptRow(hasDownloadedModels: hasDownloadedModels)

            // Per-app overrides
            ForEach(settings.appPrompts) { appPrompt in
                AppPromptRow(appPrompt: appPrompt, hasDownloadedModels: hasDownloadedModels)
            }

            // Add per-app button
            Button {
                showingAppPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.caption2)
                    Text(String(localized: "section.instructions.addApp", defaultValue: "Add app"))
                        .font(.caption)
                }
                .foregroundStyle(Color("AccentColor"))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingAppPicker) {
            InstalledAppPickerSheet(
                title: String(localized: "section.prompt.picker.title", defaultValue: "Wybierz aplikację"),
                excludedBundleIds: Set(settings.appPrompts.map(\.bundleId))
            ) { bundleId, appName in
                settings.addAppPrompt(AppPrompt(
                    bundleId: bundleId,
                    appName: appName,
                    prompt: "",
                    enabled: hasDownloadedModels
                ))
            }
        }
    }
}

private struct AllAppsPromptRow: View {
    @EnvironmentObject var settings: AppSettings
    @State private var localPrompt: String = ""
    @State private var showNoModelWarning = false
    let hasDownloadedModels: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "macwindow")
                    .frame(width: 16)
                    .foregroundStyle(settings.llmGeneralPromptEnabled ? .primary : .secondary)
                    .font(.caption)

                Text(String(localized: "section.instructions.allApps", defaultValue: "All apps"))
                    .font(.caption)
                    .foregroundStyle(settings.llmGeneralPromptEnabled ? .primary : .secondary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { settings.llmGeneralPromptEnabled },
                    set: { newValue in
                        if newValue && !hasDownloadedModels {
                            showNoModelWarning = true
                        } else {
                            showNoModelWarning = false
                            settings.llmGeneralPromptEnabled = newValue
                        }
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
            }

            if showNoModelWarning {
                Text(String(localized: "section.prompt.nomodel", defaultValue: "Pobierz model LLM, np. Gemma 4 E2B"))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if settings.llmGeneralPromptEnabled {
                PromptTextEditor(
                    text: $localPrompt,
                    placeholder: String(localized: "section.instructions.allApps.placeholder", defaultValue: "Instructions for all apps...")
                )
                .frame(minHeight: 60, maxHeight: 100)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: localPrompt) { _, newValue in
                    settings.llmPrompt = newValue
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { localPrompt = settings.llmPrompt }
        .onChange(of: hasDownloadedModels) { _, hasModels in
            if hasModels { showNoModelWarning = false }
        }
    }
}

private struct AppPromptRow: View {
    let appPrompt: AppPrompt
    let hasDownloadedModels: Bool
    @EnvironmentObject var settings: AppSettings
    @State private var localPrompt: String = ""
    @State private var showNoModelWarning = false

    private var cleanAppName: String {
        appPrompt.appName.replacingOccurrences(of: ".app", with: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let icon = appIcon(forBundleId: appPrompt.bundleId) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "app.fill")
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Text(cleanAppName)
                    .font(.caption)
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

                Toggle("", isOn: Binding(
                    get: { appPrompt.enabled },
                    set: { newValue in
                        if newValue && !hasDownloadedModels {
                            showNoModelWarning = true
                        } else {
                            showNoModelWarning = false
                            settings.toggleAppPrompt(bundleId: appPrompt.bundleId)
                        }
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
            }

            if showNoModelWarning {
                Text(String(localized: "section.prompt.nomodel", defaultValue: "Pobierz model LLM, np. Gemma 4 E2B"))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if appPrompt.enabled {
                PromptTextEditor(
                    text: $localPrompt,
                    placeholder: String(localized: String.LocalizationValue("section.prompt.perapp.placeholder \(cleanAppName)"))
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { localPrompt = appPrompt.prompt }
        .onChange(of: hasDownloadedModels) { _, hasModels in
            if hasModels { showNoModelWarning = false }
        }
    }
}
