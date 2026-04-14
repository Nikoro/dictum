import SwiftUI

@MainActor
struct RecordingPreferencesSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "section.mode", defaultValue: "Mode:"))
                    .font(.headline)
                Spacer()
                Picker("", selection: $settings.recordingModeRaw) {
                    ForEach(RecordingMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            HStack {
                Text(String(localized: "section.hotkey", defaultValue: "Hotkey:"))
                    .font(.headline)
                Spacer()
                HotkeyRecorderButton(hotkeyDescription: hotkeyDescription)
            }

            LaunchAtLoginPreferenceToggle()

            HStack {
                Text(String(localized: "section.llm.cleanup", defaultValue: "LLM processing"))
                Spacer()
                Toggle("", isOn: $settings.llmCleanupEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
        .padding()
    }

    private var hotkeyDescription: String {
        if settings.hotkeyIsModifierOnly {
            return GlobalHotkeyMonitor.modifierKeyName(settings.hotkeyKeyCode) ?? "Key \(settings.hotkeyKeyCode)"
        }

        var parts: [String] = []
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifiers))
        if modifiers.contains(.command) { parts.append("\u{2318}") }
        if modifiers.contains(.option) { parts.append("\u{2325}") }
        if modifiers.contains(.control) { parts.append("\u{2303}") }
        if modifiers.contains(.shift) { parts.append("\u{21E7}") }

        let keyName: String
        switch settings.hotkeyKeyCode {
        case 49: keyName = String(localized: "hotkey.space", defaultValue: "Space")
        case 36: keyName = String(localized: "hotkey.return", defaultValue: "Return")
        case 48: keyName = String(localized: "hotkey.tab", defaultValue: "Tab")
        case 53: keyName = String(localized: "hotkey.esc", defaultValue: "Esc")
        case 51: keyName = String(localized: "hotkey.delete", defaultValue: "Delete")
        case 76: keyName = String(localized: "hotkey.enter", defaultValue: "Enter")
        default:
            if let keyNameFromMapping = KeyCodeMapping.keyName(for: settings.hotkeyKeyCode) {
                keyName = keyNameFromMapping
            } else {
                keyName = "Key \(settings.hotkeyKeyCode)"
            }
        }

        parts.append(keyName)
        return parts.joined(separator: " ")
    }
}
