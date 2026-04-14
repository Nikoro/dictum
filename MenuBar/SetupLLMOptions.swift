import Foundation

struct LLMModelOption: Identifiable {
    let id: String
    let displayName: String
    let sizeGB: String
    let descriptionKey: String
    let recommended: Bool

    var description: String {
        String(localized: String.LocalizationValue(descriptionKey))
    }
}

let setupLLMModelOptions: [LLMModelOption] = [
    LLMModelOption(
        id: "mlx-community/gemma-4-e2b-it-4bit",
        displayName: "Gemma 4 E2B",
        sizeGB: "~3 GB",
        descriptionKey: "llm.gemma4_e2b.desc",
        recommended: true
    ),
    LLMModelOption(
        id: "mlx-community/gemma-4-e4b-it-4bit",
        displayName: "Gemma 4 E4B",
        sizeGB: "~5 GB",
        descriptionKey: "llm.gemma4_e4b.desc",
        recommended: false
    ),
    LLMModelOption(
        id: "mlx-community/gemma-4-26b-a4b-it-4bit",
        displayName: "Gemma 4 26B",
        sizeGB: "~17 GB",
        descriptionKey: "llm.gemma4_26b.desc",
        recommended: false
    )
]
