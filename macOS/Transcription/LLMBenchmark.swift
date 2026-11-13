#if DEBUG
import MLXLMCommon

@MainActor
enum LLMBenchmark {
    private static let transcripts = [
        "No więc, eee, chciałbym zapytać, czy jutro, nie, przepraszam, w piątek jest spotkanie zespołu, "
            + "bo, no, nie jestem pewien.",
        "Dzień dobry, chciałbym umówić spotkanie na jutro o dziesiątej rano.",
        "Marek Kowalski z Gdańska zamówił czterdzieści dwa egzemplarze książki Pan Tadeusz w księgarni na ulicy Długiej.",
        "Proszę przypomnieć Agnieszce, że prezentacja dla klienta z Wrocławia musi być gotowa do piątku, "
            + "a budżet nie może przekroczyć pięciu tysięcy złotych.",
        "Wczoraj wieczorem przeczytałem artykuł o sztucznej inteligencji i jej wpływie na rynek pracy. "
            + "Autor twierdzi, że w ciągu najbliższych dziesięciu lat wiele zawodów zmieni się nie do poznania."
    ]

    static func run(drafterId: String?) async -> String {
        do {
            try await ModelWarmupCoordinator.shared.loadLLMModelIfNeeded()
            let prompt = AppSettings.shared.resolvePrompt(for: nil)
            var report = try await measure("cachedPrefix", prompt: prompt)
            report += try await measure("chatSession", prompt: prompt)
            if let drafterId {
                try await LLMProcessor.shared.loadDrafter(drafterId)
                report += try await measure("cachedPrefix+mtp", prompt: prompt)
            }
            return report
        } catch {
            return "error=\(error)\n"
        }
    }

    private static func measure(_ mode: String, prompt: String) async throws -> String {
        var lines: [String] = []
        for (index, transcript) in transcripts.enumerated() {
            let start = ContinuousClock.now
            let output = mode == "chatSession"
                ? try await chatSession(prompt: prompt, transcript: transcript)
                : try await LLMProcessor.shared.cleanText(rawText: transcript, prompt: prompt)
            lines.append("\(mode) #\(index) \(ContinuousClock.now - start) | \(output)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func chatSession(prompt: String, transcript: String) async throws -> String {
        guard let container = await LLMProcessor.shared.debugModelContainer else { return "" }
        let session = ChatSession(
            container,
            instructions: prompt,
            generateParameters: GenerateParameters(maxTokens: 256, temperature: 0),
            additionalContext: ["enable_thinking": false]
        )
        let result = try await session.respond(to: "<TRANSCRIPT>\n\(transcript)\n</TRANSCRIPT>")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
