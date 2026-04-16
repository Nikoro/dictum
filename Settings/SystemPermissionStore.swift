import AVFoundation
import AppKit
import Combine

@MainActor
final class SystemPermissionStore: ObservableObject {
    static let shared = SystemPermissionStore()

    @Published var accessibilityGranted = false
    @Published var microphoneGranted = false
    @Published var screenRecordingGranted = false

    var allGranted: Bool { accessibilityGranted && microphoneGranted }

    private var pollingTimer: Timer?

    private init() {
        refresh()
    }

    func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneGranted = micStatus == .authorized
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    // MARK: - Request

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        startPolling()
    }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.microphoneGranted = granted
            }
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
        startPolling()
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    // MARK: - Polling

    func startPolling() {
        guard pollingTimer == nil else { return }
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                self.refresh()
                if self.allGranted && self.screenRecordingGranted {
                    timer.invalidate()
                    self.pollingTimer = nil
                }
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}
