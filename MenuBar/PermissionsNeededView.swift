import SwiftUI
import AVFoundation

@MainActor
struct PermissionsNeededView: View {
    @ObservedObject var permissionsStore: SystemPermissionStore

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(String(localized: "permissions.needed.title", defaultValue: "Permissions needed"))
                .font(.headline)

            Text(
                String(
                    localized: "permissions.needed.desc",
                    defaultValue: "After the update, macOS requires you to re-enable permissions."
                )
            )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                if !permissionsStore.microphoneGranted {
                    PermissionRow(
                        icon: "mic.fill",
                        title: String(localized: "setup.step1.mic.title", defaultValue: "Microphone"),
                        description: String(localized: "setup.step1.mic.desc", defaultValue: "Record voice for transcription"),
                        isGranted: false,
                        action: {
                            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                                permissionsStore.requestMicrophone()
                            } else {
                                permissionsStore.openMicrophoneSettings()
                            }
                        }
                    )
                }
                if !permissionsStore.accessibilityGranted {
                    PermissionRow(
                        icon: "hand.raised.fill",
                        title: String(localized: "setup.step1.acc.title", defaultValue: "Accessibility"),
                        description: String(localized: "setup.step1.acc.desc", defaultValue: "Global hotkey and auto-paste (Cmd+V)"),
                        isGranted: false,
                        action: {
                            permissionsStore.openAccessibilitySettings()
                        }
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

@MainActor
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
