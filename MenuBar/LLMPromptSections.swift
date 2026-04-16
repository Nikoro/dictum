import SwiftUI

// MARK: - Unified System Prompt

@MainActor
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

// MARK: - Context Sources

@MainActor
struct ContextSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "section.context", defaultValue: "Context"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            ContextToggleRow(
                icon: "rectangle.dashed.badge.record",
                title: String(localized: "section.context.screenshot", defaultValue: "Screenshot"),
                isOn: $settings.contextScreenshot
            )
            ContextToggleRow(
                icon: "text.cursor",
                title: String(localized: "section.context.selectedText", defaultValue: "Selected text"),
                isOn: $settings.contextSelectedText
            )
            ContextToggleRow(
                icon: "doc.on.clipboard",
                title: String(localized: "section.context.clipboard", defaultValue: "Clipboard"),
                isOn: $settings.contextClipboard
            )
        }
    }
}

@MainActor
struct ContextToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundStyle(isOn ? .primary : .secondary)
                .font(.caption)
            Text(title)
                .font(.caption)
                .foregroundStyle(isOn ? .primary : .secondary)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
        }
    }
}

// MARK: - Instructions (All Apps + Per-App)

@MainActor
struct InstructionsSection: View {
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
                title: String(localized: "section.prompt.picker.title", defaultValue: "Choose application"),
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

// MARK: - All Apps Prompt Row

@MainActor
struct AllAppsPromptRow: View {
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
                Text(String(localized: "section.prompt.nomodel", defaultValue: "Download an LLM model first, e.g. Gemma 4 E2B"))
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

// MARK: - Legacy sections (kept for backward compatibility)

@MainActor
struct GeneralPromptSection: View {
    @EnvironmentObject var settings: AppSettings
    @State private var localPrompt: String = ""
    @State private var showNoModelWarning = false
    let hasDownloadedModels: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
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

                Image(systemName: "text.bubble")
                    .frame(width: 18, height: 18)
                    .foregroundStyle(settings.llmGeneralPromptEnabled ? .primary : .secondary)

                Text(String(localized: "section.prompt.general", defaultValue: "General prompt"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(settings.llmGeneralPromptEnabled ? .primary : .secondary)
            }

            if showNoModelWarning {
                Text(String(localized: "section.prompt.nomodel", defaultValue: "Download an LLM model first, e.g. Gemma 4 E2B"))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if settings.llmGeneralPromptEnabled {
                PromptTextEditor(
                    text: $localPrompt,
                    placeholder: String(localized: "section.prompt.general.placeholder", defaultValue: "Enter general prompt...")
                )
                .frame(minHeight: 80, maxHeight: 120)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: localPrompt) { _, newValue in
                    settings.llmPrompt = newValue
                }

                Button(String(localized: "section.prompt.example", defaultValue: "Example prompt")) {
                    let example = String(localized: "prompt.example.content", defaultValue: "Remove fillers (uh, um, hmm). Fix punctuation and typos. Fix sentences that don't make sense. Don't change style. Return only corrected text.")
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
        .onChange(of: hasDownloadedModels) { _, hasModels in
            if hasModels { showNoModelWarning = false }
        }
    }
}

@MainActor
struct AppPromptsSection: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showingAppPicker = false
    let hasDownloadedModels: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "section.prompt.perapp", defaultValue: "Per-app prompts"))
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
                Text(String(localized: "section.prompt.perapp.empty", defaultValue: "None — general prompt will be used"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(settings.appPrompts) { appPrompt in
                AppPromptRow(appPrompt: appPrompt, hasDownloadedModels: hasDownloadedModels)
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            InstalledAppPickerSheet(
                title: String(localized: "section.prompt.picker.title", defaultValue: "Choose application"),
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

// MARK: - Per-App Prompt Row

@MainActor
struct AppPromptRow: View {
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
                if let icon = applicationIcon(forBundleId: appPrompt.bundleId) {
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
                Text(String(localized: "section.prompt.nomodel", defaultValue: "Download an LLM model first, e.g. Gemma 4 E2B"))
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
