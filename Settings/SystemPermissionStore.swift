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
        // Imported as a mutable global, so it cannot be read directly under Swift 6 strict
        // concurrency. The underlying CFString value is a constant.
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
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
        // The block deliberately ignores its Timer argument: Timer is not Sendable, so handing
        // it to the main-actor body would be a cross-isolation send. Invalidation goes through
        // `pollingTimer` instead, which is the same object.
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // Scheduled from the main actor, so the block fires on the main run loop.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refresh()
                if self.allGranted && self.screenRecordingGranted {
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
