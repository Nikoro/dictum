import SwiftUI

@MainActor
struct PopoverStatusHeader: View {
    @Environment(AppRuntimeState.self) private var runtimeState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            title
            if let statusText = stateDescription {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    }
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(stateColor)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: runtimeState.appState)
            }
        }
        .padding()
    }

    private var title: some View {
        HStack(spacing: 8) {
            Spacer()
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)
            Text("Dictum")
                .font(.title2.bold())
            Spacer()
        }
    }

    private var stateDescription: String? {
        switch runtimeState.appState {
        case .idle: nil
        case .warmingUp: String(localized: "header.warmingUp", defaultValue: "Warming up...")
        case .recording: String(localized: "header.recording", defaultValue: "Recording...")
        case .transcribing: String(localized: "header.transcribing", defaultValue: "Transcribing...")
        case .processingLLM: String(localized: "header.processingLLM", defaultValue: "Cleaning text with LLM...")
        case let .error(message): message
        }
    }

    private var isProcessing: Bool {
        switch runtimeState.appState {
        case .warmingUp, .recording, .transcribing, .processingLLM: true
        default: false
        }
    }

    private var stateColor: Color {
        switch runtimeState.appState {
        case .warmingUp: .blue
        case .recording: .red
        case .transcribing: .yellow
        case .processingLLM: .orange
        case .error: .red
        default: .secondary
        }
    }
}
