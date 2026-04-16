import AVFoundation
import SwiftUI

@MainActor
struct SetupPermissionStep: View {
    @ObservedObject var permissionsStore: SystemPermissionStore

    var body: some View {
        SetupStepContent(
            stepNumber: 1,
            title: String(localized: "setup.step1.title", defaultValue: "Permissions"),
            isDone: permissionsStore.allGranted
        ) {
            VStack(spacing: 10) {
                PermissionRow(
                    icon: "mic.fill",
                    title: String(localized: "setup.step1.mic.title", defaultValue: "Microphone"),
                    description: String(localized: "setup.step1.mic.desc", defaultValue: "Record voice for transcription"),
                    isGranted: permissionsStore.microphoneGranted,
                    action: requestMicrophone
                )
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: String(localized: "setup.step1.acc.title", defaultValue: "Accessibility"),
                    description: String(localized: "setup.step1.acc.desc", defaultValue: "Global hotkey and auto-paste (Cmd+V)"),
                    isGranted: permissionsStore.accessibilityGranted,
                    action: permissionsStore.openAccessibilitySettings
                )
                PermissionRow(
                    icon: "rectangle.dashed.badge.record",
                    title: String(localized: "setup.step1.screen.title", defaultValue: "Screen Recording"),
                    description: String(localized: "setup.step1.screen.desc", defaultValue: "Capture window for smart context"),
                    isGranted: permissionsStore.screenRecordingGranted,
                    action: {
                        if !permissionsStore.screenRecordingGranted {
                            permissionsStore.requestScreenRecording()
                        }
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func requestMicrophone() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            permissionsStore.requestMicrophone()
        } else {
            permissionsStore.openMicrophoneSettings()
        }
    }
}
