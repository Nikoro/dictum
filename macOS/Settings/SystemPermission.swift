enum SystemPermission: CaseIterable, Identifiable {
    case microphone
    case accessibility
    case screenRecording

    var id: Self {
        self
    }

    var icon: String {
        switch self {
        case .microphone: "mic.fill"
        case .accessibility: "hand.raised.fill"
        case .screenRecording: "rectangle.dashed.badge.record"
        }
    }

    var title: String {
        switch self {
        case .microphone: String(localized: "setup.step1.mic.title", defaultValue: "Microphone")
        case .accessibility: String(localized: "setup.step1.acc.title", defaultValue: "Accessibility")
        case .screenRecording: String(localized: "setup.step1.screen.title", defaultValue: "Screen Recording")
        }
    }

    var description: String {
        switch self {
        case .microphone:
            String(localized: "setup.step1.mic.desc", defaultValue: "Record voice for transcription")
        case .accessibility:
            String(localized: "setup.step1.acc.desc", defaultValue: "Global hotkey and auto-paste (Cmd+V)")
        case .screenRecording:
            String(localized: "setup.step1.screen.desc", defaultValue: "Capture window for smart context")
        }
    }
}
