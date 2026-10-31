enum TranscriptionPrompt {
    private static let precedingTextCharacterLimit = 60

    // Edge case: WhisperKit feeds prompt tokens through the decoder one step at a time (~70 ms
    // each), so a fresh dictation gets no prompt; a later chunk of a long recording gets the tail
    // of the previous one, which keeps casing and wording consistent across the cut.
    static func text(precedingText: String?) -> String? {
        guard let precedingText, !precedingText.isEmpty else { return nil }
        return String(precedingText.suffix(precedingTextCharacterLimit))
    }
}
