import SwiftUI

@MainActor
struct InstructionsSection: View {
    @Environment(AppSettings.self) private var settings
    @State private var showingAppPicker = false
    let hasDownloadedModels: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.instructions", defaultValue: "Instructions"))
                .font(.headline)

            AllAppsPromptRow(hasDownloadedModels: hasDownloadedModels)

            ForEach(settings.appPrompts) { appPrompt in
                AppPromptRow(appPrompt: appPrompt, hasDownloadedModels: hasDownloadedModels)
            }

            addAppButton
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

    private var addAppButton: some View {
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
}

@MainActor
struct AllAppsPromptRow: View {
    @Environment(AppSettings.self) private var settings
    @State private var localPrompt: String = ""
    let hasDownloadedModels: Bool

    var body: some View {
        InstructionPromptCard(
            title: String(localized: "section.instructions.allApps", defaultValue: "All apps"),
            isEnabled: settings.llmGeneralPromptEnabled,
            hasDownloadedModels: hasDownloadedModels,
            placeholder: String(
                localized: "section.instructions.allApps.placeholder",
                defaultValue: "Instructions for all apps..."
            ),
            prompt: $localPrompt,
            onEnabledChange: { settings.llmGeneralPromptEnabled = $0 },
            icon: {
                Image(systemName: "macwindow")
                    .frame(width: 16)
                    .foregroundStyle(settings.llmGeneralPromptEnabled ? .primary : .secondary)
                    .font(.caption)
            },
            accessory: { EmptyView() }
        )
        .onAppear { localPrompt = settings.llmPrompt }
        .onChange(of: localPrompt) { _, newValue in
            settings.llmPrompt = newValue
        }
    }
}

@MainActor
struct AppPromptRow: View {
    let appPrompt: AppPrompt
    let hasDownloadedModels: Bool
    @Environment(AppSettings.self) private var settings
    @State private var localPrompt: String = ""

    var body: some View {
        InstructionPromptCard(
            title: appPrompt.displayName,
            isEnabled: appPrompt.enabled,
            hasDownloadedModels: hasDownloadedModels,
            placeholder: String(localized: String
                .LocalizationValue("section.prompt.perapp.placeholder \(appPrompt.displayName)")),
            prompt: $localPrompt,
            onEnabledChange: { _ in settings.toggleAppPrompt(bundleId: appPrompt.bundleId) },
            icon: { appIcon },
            accessory: { removeButton }
        )
        .onAppear { localPrompt = appPrompt.prompt }
        .onChange(of: localPrompt) { _, newValue in
            settings.updateAppPrompt(bundleId: appPrompt.bundleId, prompt: newValue)
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = applicationIcon(forBundleId: appPrompt.bundleId) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "app.fill")
                .frame(width: 16)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private var removeButton: some View {
        Button {
            settings.removeAppPrompt(bundleId: appPrompt.bundleId)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "a11y.remove", defaultValue: "Remove"))
    }
}
