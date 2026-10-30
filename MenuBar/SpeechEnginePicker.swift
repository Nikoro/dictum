import SwiftUI

@MainActor
struct SpeechEnginePicker: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ParakeetModelStore.self) private var parakeet

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("", selection: Bindable(settings).sttEngine) {
                ForEach(SpeechEngine.allCases, id: \.self) { engine in
                    Text(engine.displayName).tag(engine)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if settings.sttEngine == .parakeet {
                parakeetStatus
            }
        }
    }

    @ViewBuilder
    private var parakeetStatus: some View {
        if parakeet.isDownloaded {
            Text(String(
                localized: "engine.parakeet.ready",
                defaultValue: "Many times faster, slightly less accurate with names."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if parakeet.isDownloading {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(String(localized: "engine.parakeet.downloading", defaultValue: "Downloading the Parakeet model…"))
                    .font(.caption)
            }
        } else {
            Button(String(localized: "engine.parakeet.download", defaultValue: "Download Parakeet model (~600 MB)")) {
                parakeet.download()
            }
            .font(.caption)
        }
        if let error = parakeet.downloadError {
            ModelDownloadErrorView(errorMessage: error) { parakeet.downloadError = nil }
        }
    }
}
