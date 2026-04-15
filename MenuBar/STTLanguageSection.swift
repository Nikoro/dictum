import SwiftUI

struct STTLanguageSection: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showingAppPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.stt.language", defaultValue: "Recognition language"))
                .font(.headline)

            // General language picker
            HStack {
                Text(String(localized: "section.stt.language.general", defaultValue: "General"))
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
                Text(String(localized: "section.stt.language.perapp", defaultValue: "Language per app"))
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
                Text(String(localized: "section.stt.language.perapp.empty", defaultValue: "None — general language will be used"))
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

            if let icon = applicationIcon(forBundleId: appLang.bundleId) {
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
