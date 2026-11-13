enum TranscriptionPrompt {
    private static let precedingTextCharacterLimit = 60

    static func text(precedingText: String?) -> String? {
        guard let precedingText, !precedingText.isEmpty else { return nil }
        return String(precedingText.suffix(precedingTextCharacterLimit))
    }
}
