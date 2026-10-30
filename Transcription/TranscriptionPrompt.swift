enum TranscriptionPrompt {
    private static let precedingTextCharacterLimit = 60

    private static let styleSentences: [String: String] = [
        "pl": "Cześć, jak się masz? Miło cię poznać.",
        "en": "Hello, how are you? Nice to meet you.",
        "de": "Hallo, wie geht es dir? Schön, dich kennenzulernen.",
        "fr": "Bonjour, comment ça va ? Ravi de vous rencontrer.",
        "es": "Hola, ¿cómo estás? Encantado de conocerte.",
        "it": "Ciao, come stai? Piacere di conoscerti.",
        "pt": "Olá, como você está? Prazer em conhecê-lo.",
        "uk": "Привіт, як справи? Радий познайомитися.",
        "cs": "Ahoj, jak se máš? Rád tě poznávám.",
        "nl": "Hallo, hoe gaat het? Leuk je te ontmoeten.",
        "ru": "Привет, как дела? Приятно познакомиться.",
        "sv": "Hej, hur mår du? Trevligt att träffas.",
        "tr": "Merhaba, nasılsın? Tanıştığımıza memnun oldum.",
        "ja": "こんにちは、お元気ですか？はじめまして。",
        "ko": "안녕하세요, 잘 지내세요? 만나서 반갑습니다.",
        "zh": "你好，你好吗？很高兴认识你。"
    ]

    // Edge case: Whisper copies the casing and punctuation of its prompt, so a short, well
    // punctuated sentence in the target language yields sentences instead of a lowercase run.
    // Continuing a recording, the tail of the previous chunk keeps the two halves consistent.
    static func text(language: String?, precedingText: String?) -> String? {
        if let precedingText, !precedingText.isEmpty {
            return String(precedingText.suffix(precedingTextCharacterLimit))
        }
        return language.flatMap { styleSentences[$0] }
    }
}
