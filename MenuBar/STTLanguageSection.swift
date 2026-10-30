import SwiftUI

struct STTLanguageSection: View {
    @Environment(AppSettings.self) private var settings
    @State private var showingAppPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.stt.language", defaultValue: "Recognition language"))
                .font(.headline)
            generalLanguagePicker
            perAppHeader

            if settings.appSTTLanguages.isEmpty {
                Text(String(
                    localized: "section.stt.language.perapp.empty",
                    defaultValue: "None — general language will be used"
                ))
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
                title: String(localized: "section.stt.language.picker.title", defaultValue: "Choose application"),
                excludedBundleIds: Set(settings.appSTTLanguages.map(\.bundleId))
            ) { bundleId, appName in
                settings.addAppSTTLanguage(AppSTTLanguage(bundleId: bundleId, appName: appName, language: .auto))
            }
        }
    }

    private var generalLanguagePicker: some View {
        PreferenceRow(title: String(localized: "section.stt.language.general", defaultValue: "General")) {
            STTLanguagePicker(selection: Bindable(settings).sttLanguage)
                .fixedSize()
        }
    }

    private var perAppHeader: some View {
        PreferenceRow(title: String(localized: "section.stt.language.perapp", defaultValue: "Language per app")) {
            Button {
                showingAppPicker = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "a11y.addApp", defaultValue: "Add app"))
        }
    }
}

private struct STTLanguagePicker: View {
    @Binding var selection: STTLanguage

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(STTLanguage.allCases, id: \.self) { lang in
                Text(lang.displayName).tag(lang)
            }
        }
        .labelsHidden()
    }
}

private struct AppSTTLanguageRow: View {
    let appLang: AppSTTLanguage
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: Binding(
                get: { appLang.enabled },
                set: { _ in settings.toggleAppSTTLanguage(bundleId: appLang.bundleId) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)

            appIcon
            Text(appLang.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(appLang.enabled ? .primary : .secondary)

            Spacer()

            STTLanguagePicker(selection: Binding(
                get: { appLang.language },
                set: { settings.updateAppSTTLanguage(bundleId: appLang.bundleId, language: $0) }
            ))
            .controlSize(.small)
            .fixedSize()

            removeButton
        }
        .padding(8)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var removeButton: some View {
        Button {
            settings.removeAppSTTLanguage(bundleId: appLang.bundleId)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "a11y.remove", defaultValue: "Remove"))
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = applicationIcon(forBundleId: appLang.bundleId) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: "app.fill")
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
        }
    }
}
