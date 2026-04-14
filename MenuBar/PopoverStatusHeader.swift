import SwiftUI

@MainActor
struct PopoverStatusHeader: View {
    @EnvironmentObject var runtimeState: AppRuntimeState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Spacer()
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("Dictum")
                    .font(.title2.bold())
                Spacer()
            }

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

    private var stateDescription: String? {
        switch runtimeState.appState {
        case .idle: return nil
        case .warmingUp: return String(localized: "header.warmingUp", defaultValue: "Warming up...")
        case .recording: return String(localized: "header.recording", defaultValue: "Recording...")
        case .transcribing: return String(localized: "header.transcribing", defaultValue: "Transcribing...")
        case .processingLLM: return String(localized: "header.processingLLM", defaultValue: "Cleaning text with LLM...")
        case .done: return String(localized: "header.done", defaultValue: "Done \u{2014} text pasted")
        case .error(let message): return message
        }
    }

    private var isProcessing: Bool {
        switch runtimeState.appState {
        case .warmingUp, .recording, .transcribing, .processingLLM: return true
        default: return false
        }
    }

    private var stateColor: Color {
        switch runtimeState.appState {
        case .warmingUp: return .blue
        case .recording: return .red
        case .transcribing: return .yellow
        case .processingLLM: return .orange
        case .done: return .green
        case .error: return .yellow
        default: return .secondary
        }
    }
}
