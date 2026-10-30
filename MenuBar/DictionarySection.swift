import SwiftUI

@MainActor
struct DictionarySection: View {
    @Environment(WordReplacementStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "section.dictionary", defaultValue: "Dictionary"))
                .font(.headline)

            if store.replacements.isEmpty {
                Text(String(
                    localized: "section.dictionary.empty",
                    defaultValue: "Fix words that are always misheard, e.g. \"dick tum\" → \"Dictum\"."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(Bindable(store).replacements) { $rule in
                WordReplacementRow(rule: $rule) { store.remove(rule.id) }
            }

            Button {
                store.add()
            } label: {
                Label(String(localized: "section.dictionary.add", defaultValue: "Add word"), systemImage: "plus")
                    .font(.caption)
                    .foregroundStyle(Color("AccentColor"))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

private struct WordReplacementRow: View {
    @Binding var rule: WordReplacement
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            TextField(String(localized: "section.dictionary.heard", defaultValue: "Heard"), text: $rule.heard)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(String(localized: "section.dictionary.replacement", defaultValue: "Replace with"), text: $rule.replacement)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "a11y.remove", defaultValue: "Remove"))
        }
        .textFieldStyle(.roundedBorder)
        .font(.caption)
    }
}
