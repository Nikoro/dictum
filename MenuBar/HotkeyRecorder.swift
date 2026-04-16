import SwiftUI

@MainActor
final class HotkeyRecorderModel: ObservableObject {
    @Published var isRecording = false

    private var keyMonitor: Any?
    private var flagsMonitor: Any?

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true

        DictationPipeline.shared.hotkeyMonitor.stop()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let keyCode = Int(event.keyCode)

            if keyCode == 53 {
                self.stopRecording()
                return nil
            }

            let modifiers = Int(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue)
            self.applyHotkey(keyCode: keyCode, modifiers: modifiers, isModifierOnly: false)
            return nil
        }

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            let keyCode = Int(event.keyCode)
            guard GlobalHotkeyMonitor.isModifierKeyCode(keyCode) else { return event }

            let flag = GlobalHotkeyMonitor.modifierFlag(forKeyCode: keyCode)
            let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
            if flags.contains(flag) {
                self.applyHotkey(keyCode: keyCode, modifiers: 0, isModifierOnly: true)
                return nil
            }
            return event
        }
    }

    func stopRecording() {
        removeMonitors()
        isRecording = false
        DictationPipeline.shared.setupHotkey()
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

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        Task { @MainActor in
            DictationPipeline.shared.setupHotkey()
        }
    }
}

@MainActor
struct HotkeyRecorderButton: View {
    @StateObject private var recorder = HotkeyRecorderModel()
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
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .font(.system(.body, design: .monospaced))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(recorder.isRecording ? Color("AccentColor") : .clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

enum KeyCodeMapping {
    private static let mapping: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            50: "`",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 107: "F14",
            109: "F10", 111: "F12", 113: "F15",
            118: "F4", 119: "F2", 120: "F1",
            121: "Page Down", 122: "F16", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    static func keyName(for keyCode: Int) -> String? {
        mapping[keyCode]
    }
}
