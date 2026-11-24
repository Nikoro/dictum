import SwiftUI

@MainActor
struct AudioPreferencesSection: View {
    @Environment(AppSettings.self) private var settings
    @State private var inputDevices: [AudioInputDevice] = []
    @State private var defaultInputName: String?

    private static let idleUnloadOptions = [0, 5, 15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PreferenceRow(
                title: String(localized: "section.microphone", defaultValue: "Microphone"),
                maxControlWidth: .infinity
            ) {
                Picker("", selection: microphoneSelection) {
                    Text(defaultInputLabel).tag("")
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
        .onAppear(perform: refreshInputs)
        .onReceive(NotificationCenter.default.publisher(for: AudioInputDevices.didChange)) { _ in
            refreshInputs()
        }
    }

    private var microphoneSelection: Binding<String> {
        Binding {
            inputDevices.contains { $0.uid == settings.inputDeviceUID } ? settings.inputDeviceUID : ""
        } set: { uid in
            settings.inputDeviceUID = uid
        }
    }

    private var defaultInputLabel: String {
        guard let defaultInputName else {
            return String(localized: "section.microphone.systemDefault", defaultValue: "System default")
        }
        return String(
            localized: "section.microphone.systemDefault.named",
            defaultValue: "System default (\(defaultInputName))"
        )
    }

    private func refreshInputs() {
        inputDevices = AudioInputDevices.all()
        let defaultID = AudioInputDevices.systemDefaultInputID()
        defaultInputName = inputDevices.first { $0.id == defaultID }?.name
    }

    private static func idleUnloadLabel(_ minutes: Int) -> String {
        guard minutes > 0 else {
            return String(localized: "section.idleUnload.never", defaultValue: "Never")
        }
        let count = String(minutes)
        return String(localized: String.LocalizationValue("section.idleUnload.minutes \(count)"))
    }
}
