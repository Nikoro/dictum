import SwiftUI

@MainActor
@Observable
final class HotkeyRecorderModel {
    var isRecording = false

    @ObservationIgnored private var keyMonitor: Any?
    @ObservationIgnored private var flagsMonitor: Any?

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true

        DictationHotkeyController.shared.unregister()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let keyCode = Int(event.keyCode)

            if keyCode == Int(KeyCode.escape) {
                stopRecording()
                return nil
            }

            let modifiers = Int(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue)
            applyHotkey(keyCode: keyCode, modifiers: modifiers, isModifierOnly: false)
            return nil
        }

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            let keyCode = Int(event.keyCode)
            guard ModifierKey.isModifier(keyCode) else { return event }

            let flag = ModifierKey.flag(forKeyCode: keyCode)
            let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
            if flags.contains(flag) {
                applyHotkey(keyCode: keyCode, modifiers: 0, isModifierOnly: true)
                return nil
            }
            return event
        }
    }

    func stopRecording() {
        removeMonitors()
        isRecording = false
        DictationHotkeyController.shared.register()
    }

    private func applyHotkey(keyCode: Int, modifiers: Int, isModifierOnly: Bool) {
        let settings = AppSettings.shared
        settings.hotkeyKeyCode = keyCode
        settings.hotkeyModifiers = modifiers
        settings.hotkeyIsModifierOnly = isModifierOnly
        stopRecording()
    }

    private func removeMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
    }

    // Edge case: isolated, because the event monitors are not Sendable.
    isolated deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
        }
        Task { @MainActor in
            DictationHotkeyController.shared.register()
        }
    }
}

@MainActor
struct HotkeyRecorderButton: View {
    @State private var recorder = HotkeyRecorderModel()
    let hotkeyDescription: String

    var body: some View {
        Button {
            if recorder.isRecording {
                recorder.stopRecording()
            } else {
                recorder.startRecording()
            }
        } label: {
            Text(recorder.isRecording
                ? String(localized: "section.hotkey.press", defaultValue: "Press a key...")
                : hotkeyDescription)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(recorder.isRecording ? Color("AccentColor").opacity(0.2) : Color(nsColor: .quaternaryLabelColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(recorder.isRecording ? Color("AccentColor") : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
