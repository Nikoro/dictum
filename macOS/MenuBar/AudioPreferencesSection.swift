import SwiftUI

@MainActor
struct AudioPreferencesSection: View {
    @Environment(AppSettings.self) private var settings
    @State private var inputDevices: [AudioInputDevice] = []

    private static let idleUnloadOptions = [0, 5, 15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PreferenceRow(title: String(localized: "section.microphone", defaultValue: "Microphone")) {
                Picker("", selection: Bindable(settings).inputDeviceUID) {
                    Text(String(localized: "section.microphone.systemDefault", defaultValue: "System default")).tag("")
                    ForEach(inputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .labelsHidden()
            }
            PreferenceRow(title: String(localized: "section.idleUnload", defaultValue: "Free memory after")) {
                Picker("", selection: Bindable(settings).modelIdleUnloadMinutes) {
                    ForEach(Self.idleUnloadOptions, id: \.self) { minutes in
                        Text(Self.idleUnloadLabel(minutes)).tag(minutes)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .onAppear { inputDevices = AudioInputDevices.all() }
    }

    private static func idleUnloadLabel(_ minutes: Int) -> String {
        guard minutes > 0 else {
            return String(localized: "section.idleUnload.never", defaultValue: "Never")
        }
        let count = String(minutes)
        return String(localized: String.LocalizationValue("section.idleUnload.minutes \(count)"))
    }
}
