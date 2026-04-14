import SwiftUI

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

                Text(String(localized: "section.prompt.general", defaultValue: "Prompt ogólny"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(settings.llmGeneralPromptEnabled ? .primary : .secondary)
            }

            if showNoModelWarning {
                Text(String(localized: "section.prompt.nomodel", defaultValue: "Pobierz model LLM, np. Gemma 4 E2B"))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if settings.llmGeneralPromptEnabled {
                PromptTextEditor(
                    text: $localPrompt,
                    placeholder: String(localized: "section.prompt.general.placeholder", defaultValue: "Wpisz prompt ogólny...")
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
                AppPromptRow(appPrompt: appPrompt, hasDownloadedModels: hasDownloadedModels)
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
                    prompt: "",
                    enabled: hasDownloadedModels
                ))
            }
        }
    }
}

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
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { localPrompt = appPrompt.prompt }
        .onChange(of: hasDownloadedModels) { _, hasModels in
            if hasModels { showNoModelWarning = false }
        }
    }
}
