import AppKit
import AVFoundation
import Observation

@MainActor
@Observable
final class SystemPermissionStore {
    static let shared = SystemPermissionStore()

    var accessibilityGranted = false
    var microphoneGranted = false
    var screenRecordingGranted = false

    var allGranted: Bool {
        accessibilityGranted && microphoneGranted
    }

    @ObservationIgnored private var pollingTimer: Timer?

    private init() {
        refresh()
    }

    func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneGranted = micStatus == .authorized
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    func requestAccessibility() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        startPolling()
    }

    func isGranted(_ permission: SystemPermission) -> Bool {
        switch permission {
        case .microphone: microphoneGranted
        case .accessibility: accessibilityGranted
        case .screenRecording: screenRecordingGranted
        }
    }

    func request(_ permission: SystemPermission) {
        switch permission {
        case .microphone:
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    DispatchQueue.main.async {
                        self?.microphoneGranted = granted
                    }
                }
            } else {
                openPrivacySettings(anchor: "Privacy_Microphone")
            }
        case .accessibility:
            openPrivacySettings(anchor: "Privacy_Accessibility")
        case .screenRecording:
            guard !screenRecordingGranted else { return }
            CGRequestScreenCaptureAccess()
            startPolling()
        }
    }

    private func openPrivacySettings(anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    func startPolling() {
        guard pollingTimer == nil else { return }
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refresh()
                if self.allGranted, self.screenRecordingGranted {
                    self.stopPolling()
                }
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}
