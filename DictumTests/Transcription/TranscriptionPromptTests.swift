@testable import Dictum
import Testing

struct TranscriptionPromptTests {
    @Test
    func `a fresh dictation is decoded without a prompt, which costs one decoder step per token`() {
        #expect(TranscriptionPrompt.text(precedingText: nil) == nil)
        #expect(TranscriptionPrompt.text(precedingText: "") == nil)
    }

    @Test
    func `a later chunk is prompted with the end of the previous one to keep both halves consistent`() {
        let previous = String(repeating: "a", count: 100) + " koniec zdania."

        let prompt = TranscriptionPrompt.text(precedingText: previous)

        #expect(prompt?.hasSuffix("koniec zdania.") == true)
        #expect((prompt?.count ?? 0) <= 60)
    }
}
