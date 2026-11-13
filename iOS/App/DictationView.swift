import SwiftUI

struct DictationView: View {
    @Bindable var dictation: DictationSession
    @State private var testText = ""
    @FocusState private var testFieldFocused: Bool
    @State private var editorFrame = CGRect.zero

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Dictum")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .task { await dictation.refreshModelInventory() }
                .safeAreaInset(edge: .bottom) {
                    if !testFieldFocused {
                        versionFooter
                    }
                }
        }
        .simultaneousGesture(
            SpatialTapGesture(coordinateSpace: .global).onEnded { value in
                if !editorFrame.contains(value.location) {
                    testFieldFocused = false
                }
            },
            including: testFieldFocused ? .all : .subviews
        )
    }

    private var content: some View {
        Form {
            Section {
                SpeechModelList(dictation: dictation)
                ModelPreparationView(preparation: dictation.preparation, preparing: dictation.preparing, showsStorage: false)
                status
            } header: {
                Text(String(localized: "ios.model"))
            }
            Section {
                TextEditor(text: $testText)
                    .focused($testFieldFocused)
                    .frame(minHeight: 180)
                    .accessibilityLabel(String(localized: "ios.test_field"))
                    .accessibilityIdentifier("dictation-test-editor")
                    .onGeometryChange(for: CGRect.self) { geometry in
                        geometry.frame(in: .global)
                    } action: { editorFrame = $0 }
            } header: {
                Text(String(localized: "ios.test_field"))
            } footer: {
                Text(String(localized: "ios.test_hint"))
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var versionFooter: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return Text(String(localized: "ios.version \(version) \(build)"))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .accessibilityIdentifier("app-version")
    }

    @ViewBuilder private var status: some View {
        if let error = dictation.errorMessage {
            Text(error).font(.footnote).foregroundStyle(.red)
            Button(String(localized: "ios.retry")) { Task { await dictation.activate() } }
        } else if let message = dictation.session.issue?.message {
            Text(message).font(.footnote).foregroundStyle(.orange)
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(String(localized: "ios.keyboard_setup"), systemImage: "keyboard") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                Task { await UIApplication.shared.open(url) }
            }
            .labelStyle(.iconOnly)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await dictation.setMicrophoneEnabled(!dictation.isActive) }
            } label: {
                Image(systemName: dictation.isActive ? "mic.fill" : "mic.slash")
                    .foregroundStyle(microphoneColor)
            }
            .accessibilityLabel(String(localized: dictation.isActive ? "ios.pause_microphone" : "ios.resume_microphone"))
            .accessibilityValue(String(localized: dictation.isActive ? "ios.ready_short" : "ios.paused_short"))
            .disabled(dictation.preparing || dictation.starting || isBusy)
        }
    }

    private var isBusy: Bool {
        dictation.session.phase == .recording || dictation.session.phase == .transcribing
    }

    private var microphoneColor: Color {
        if dictation.session.phase == .recording {
            return .orange
        }
        return dictation.isActive ? .green : .yellow
    }
}
