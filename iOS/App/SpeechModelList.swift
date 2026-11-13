import SwiftUI

struct SpeechModelList: View {
    @Bindable var dictation: DictationSession

    var body: some View {
        ForEach(IOSSpeechModel.allCases) { model in
            Button {
                Task { await dictation.chooseModel(model) }
            } label: {
                row(model)
            }
            .buttonStyle(.plain)
            .disabled(dictation.preparing || dictation.starting || isBusy)
            .accessibilityIdentifier("speech-model-\(model.rawValue)")
            .accessibilityAddTraits(dictation.useUltra == model.usesUltra ? .isSelected : [])
        }
    }

    private func row(_ model: IOSSpeechModel) -> some View {
        let selected = dictation.useUltra == model.usesUltra
        let installation = dictation.installations[model]
        return HStack(spacing: 12) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Color.accentColor : .secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(installation?.bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
                        ?? model.approximateSize)
                    Text("·")
                    Text(String(localized: installation?.installed == true ? "ios.model.installed" : "ios.model.not_installed"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }

    private var isBusy: Bool {
        dictation.session.phase == .recording || dictation.session.phase == .transcribing
    }
}
