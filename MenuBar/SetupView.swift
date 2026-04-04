import SwiftUI
import AVFoundation

private struct LLMModelOption: Identifiable {
    let id: String
    let displayName: String
    let sizeGB: String
    let descriptionKey: String
    let recommended: Bool

    var description: String {
        String(localized: String.LocalizationValue(descriptionKey))
    }
}

private let llmModelOptions: [LLMModelOption] = [
    LLMModelOption(
        id: "mlx-community/gemma-4-e2b-it-4bit",
        displayName: "Gemma 4 E2B",
        sizeGB: "~3 GB",
        descriptionKey: "llm.gemma4_e2b.desc",
        recommended: true
    ),
    LLMModelOption(
        id: "mlx-community/gemma-4-e4b-it-4bit",
        displayName: "Gemma 4 E4B",
        sizeGB: "~5 GB",
        descriptionKey: "llm.gemma4_e4b.desc",
        recommended: false
    ),
    LLMModelOption(
        id: "mlx-community/gemma-4-26b-a4b-it-4bit",
        displayName: "Gemma 4 26B",
        sizeGB: "~17 GB",
        descriptionKey: "llm.gemma4_26b.desc",
        recommended: false
    ),
]

struct SetupView: View {
    @ObservedObject var permissions: PermissionsManager
    @ObservedObject var whisperManager: WhisperModelManager
    @EnvironmentObject var settings: AppSettings

    @EnvironmentObject var pipeline: DictationPipeline
    @State private var downloadedLLMId: String? = UserDefaults.standard.string(forKey: "llmDownloadedModelId")

    private var permissionsDone: Bool { permissions.allGranted }
    private var sttDone: Bool { whisperManager.downloadedModelIds.contains(settings.sttModelId) }
    private var llmDone: Bool {
        guard let id = downloadedLLMId else { return false }
        return pipeline.downloadedModelsManager.downloadedModels.contains { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image("AppLogo")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("Dictum")
                        .font(.title.bold())
                    Text(String(localized: "setup.title", defaultValue: "Setup"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                // MARK: Step 1 — Permissions
                SetupStepHeader(
                    number: 1,
                    title: String(localized: "setup.step1.title", defaultValue: "Permissions"),
                    isDone: permissionsDone
                )

                VStack(spacing: 10) {
                    PermissionRow(
                        icon: "mic.fill",
                        title: String(localized: "setup.step1.mic.title", defaultValue: "Microphone"),
                        description: String(localized: "setup.step1.mic.desc", defaultValue: "Record voice for transcription"),
                        isGranted: permissions.microphoneGranted,
                        action: {
                            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                                permissions.requestMicrophone()
                            } else {
                                permissions.openMicrophoneSettings()
                            }
                        }
                    )
                    PermissionRow(
                        icon: "hand.raised.fill",
                        title: String(localized: "setup.step1.acc.title", defaultValue: "Accessibility"),
                        description: String(localized: "setup.step1.acc.desc", defaultValue: "Global hotkey and auto-paste (Cmd+V)"),
                        isGranted: permissions.accessibilityGranted,
                        action: {
                            permissions.openAccessibilitySettings()
                        }
                    )
                    PermissionRow(
                        icon: "rectangle.dashed.badge.record",
                        title: String(localized: "setup.step1.screen.title", defaultValue: "Screen Recording"),
                        description: String(localized: "setup.step1.screen.desc", defaultValue: "Capture window for smart context"),
                        isGranted: permissions.screenRecordingGranted,
                        action: {
                            if !permissions.screenRecordingGranted {
                                permissions.requestScreenRecording()
                            }
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // MARK: Step 2 — Model STT
                SetupStepHeader(
                    number: 2,
                    title: String(localized: "setup.step2.title", defaultValue: "Speech recognition model"),
                    isDone: sttDone
                )

                if permissionsDone {
                    VStack(spacing: 8) {
                        ForEach(WhisperModelManager.defaultModels) { model in
                            SetupModelRow(
                                model: model,
                                isSelected: settings.sttModelId == model.id,
                                isDownloaded: whisperManager.downloadedModelIds.contains(model.id),
                                isDownloading: whisperManager.downloadingModelId == model.id,
                                downloadProgress: whisperManager.downloadingModelId == model.id ? whisperManager.downloadProgress : 0,
                                onSelect: {
                                    settings.sttModelId = model.id
                                    whisperManager.activeModelId = model.id
                                },
                                onDownload: {
                                    settings.sttModelId = model.id
                                    whisperManager.downloadAndActivate(model.id)
                                },
                                onCancel: {
                                    whisperManager.cancelDownload()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                } else {
                    Text(String(localized: "setup.step1.locked", defaultValue: "Enable permissions above first."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }

                // MARK: Step 3 — Model LLM (optional)
                SetupStepHeader(
                    number: 3,
                    title: String(localized: "setup.step3.title", defaultValue: "LLM text processing (optional)"),
                    isDone: llmDone
                )

                if sttDone {
                    VStack(spacing: 8) {
                        ForEach(llmModelOptions) { model in
                            SetupLLMRow(
                                model: model,
                                isSelected: settings.llmModelId == model.id,
                                isDownloaded: downloadedLLMId == model.id,
                                isDownloading: pipeline.llmDownloadingModelId == model.id,
                                downloadProgress: pipeline.llmDownloadingModelId == model.id ? pipeline.llmDownloadProgress : 0,
                                onSelect: {
                                    settings.llmModelId = model.id
                                },
                                onDownload: {
                                    settings.llmModelId = model.id
                                    pipeline.downloadLLMModel(model.id)
                                    // Track completion for setup step
                                    Task {
                                        // Wait for download to finish
                                        while pipeline.llmIsDownloading { try? await Task.sleep(for: .milliseconds(200)) }
                                        if pipeline.llmDownloadError == nil {
                                            downloadedLLMId = model.id
                                            settings.llmCleanupEnabled = true
                                            UserDefaults.standard.set(model.id, forKey: "llmDownloadedModelId")
                                            pipeline.warmUpModels()
                                        }
                                    }
                                },
                                onCancel: {
                                    pipeline.cancelLLMDownload()
                                }
                            )
                        }

                        Button(String(localized: "setup.step3.skip", defaultValue: "Skip \u{2014} use transcription only")) {
                            settings.llmCleanupEnabled = false
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                } else {
                    Text(String(localized: "setup.step2.locked", defaultValue: "Download STT model first."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }

                Spacer(minLength: 12)

                HStack {
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Image(systemName: "power")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)

                    Spacer()

                    Text("Wersja: \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Balance spacer for power button width
                    Color.clear
                        .frame(width: 16, height: 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Setup Helpers

private struct SetupStepHeader: View {
    let number: Int
    let title: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : Color("AccentColor"))
                    .frame(width: 22, height: 22)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Text(title)
                .font(.subheadline.bold())
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

private struct SetupModelRow: View {
    let model: WhisperModelInfo
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void
    var onCancel: (() -> Void)?

    private var isRecommended: Bool { model.isRecommended }

    var body: some View {
        Button(action: {
            if isDownloaded {
                onSelect()
            } else if !isDownloading {
                onDownload()
            }
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .green : .secondary)
                        .font(.body)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(model.displayName)
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                            if isRecommended {
                                Text(String(localized: "setup.recommended", defaultValue: "Recommended"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color("AccentColor"), in: Capsule())
                            }
                        }
                        if !isDownloading {
                            Text(model.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text(model.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.orange)

                    if isDownloading {
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    } else if isDownloaded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color("AccentColor"))
                            .font(.body)
                    }
                }
                .padding(10)

                if isDownloading {
                    ProgressView(value: downloadProgress)
                        .tint(Color("AccentColor"))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
            }
            .background(
                isSelected ? Color("AccentColor").opacity(0.08) : Color(nsColor: .quaternarySystemFill),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color("AccentColor").opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SetupLLMRow: View {
    let model: LLMModelOption
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void
    var onCancel: (() -> Void)?

    var body: some View {
        Button(action: {
            if isDownloaded {
                onSelect()
            } else if !isDownloading {
                onDownload()
            }
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: isSelected && isDownloaded ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected && isDownloaded ? .green : .secondary)
                        .font(.body)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(model.displayName)
                                .font(.subheadline)
                                .fontWeight(isSelected ? .semibold : .regular)
                            if model.recommended {
                                Text(String(localized: "setup.recommended", defaultValue: "Recommended"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color("AccentColor"), in: Capsule())
                            }
                        }
                        Text(model.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(model.sizeGB)
                        .font(.caption)
                        .foregroundStyle(.orange)

                    if isDownloading {
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                        Button {
                            onCancel?()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else if isDownloaded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color("AccentColor"))
                            .font(.body)
                    }
                }
                .padding(10)

                if isDownloading {
                    ProgressView(value: downloadProgress)
                        .tint(Color("AccentColor"))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
            }
            .background(
                isSelected ? Color("AccentColor").opacity(0.08) : Color(nsColor: .quaternarySystemFill),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color("AccentColor").opacity(0.3) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Permissions Needed (post-update)

struct PermissionsNeededView: View {
    @ObservedObject var permissions: PermissionsManager

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(String(localized: "permissions.needed.title", defaultValue: "Permissions needed"))
                .font(.headline)

            Text(String(localized: "permissions.needed.desc", defaultValue: "After the update, macOS requires you to re-enable permissions."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                if !permissions.microphoneGranted {
                    PermissionRow(
                        icon: "mic.fill",
                        title: String(localized: "setup.step1.mic.title", defaultValue: "Microphone"),
                        description: String(localized: "setup.step1.mic.desc", defaultValue: "Record voice for transcription"),
                        isGranted: false,
                        action: {
                            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                                permissions.requestMicrophone()
                            } else {
                                permissions.openMicrophoneSettings()
                            }
                        }
                    )
                }
                if !permissions.accessibilityGranted {
                    PermissionRow(
                        icon: "hand.raised.fill",
                        title: String(localized: "setup.step1.acc.title", defaultValue: "Accessibility"),
                        description: String(localized: "setup.step1.acc.desc", defaultValue: "Global hotkey and auto-paste (Cmd+V)"),
                        isGranted: false,
                        action: {
                            permissions.openAccessibilitySettings()
                        }
                    )
                }
                if !permissions.screenRecordingGranted {
                    PermissionRow(
                        icon: "rectangle.dashed.badge.record",
                        title: String(localized: "setup.step1.screen.title", defaultValue: "Screen Recording"),
                        description: String(localized: "setup.step1.screen.desc", defaultValue: "Capture window for smart context"),
                        isGranted: false,
                        action: {
                            permissions.requestScreenRecording()
                        }
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(isGranted ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button(String(localized: "setup.step1.enable", defaultValue: "Enable")) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
