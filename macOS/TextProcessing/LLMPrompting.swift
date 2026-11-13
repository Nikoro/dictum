import CoreImage
import MLXLMCommon

enum LLMPrompting {
    static let disableThinking: [String: any Sendable] = ["enable_thinking": false]

    static func outputTokenBudget(for rawText: String) -> Int {
        let estimatedInputTokens = rawText.count / 3
        return min(max(estimatedInputTokens * 2, 256), 2048)
    }

    static func userMessage(rawText: String, context: DictationContext?) -> String {
        let blocks: [(tag: String, content: String?)] = [
            ("APP", context?.appName),
            ("SELECTED_TEXT", context?.selectedText),
            ("CLIPBOARD", context?.clipboardText),
            ("SCREEN_TEXT", context?.ocrText),
            ("TRANSCRIPT", rawText)
        ]
        return blocks
            .compactMap { block in
                guard let content = block.content, !content.isEmpty else { return nil }
                return "<\(block.tag)>\n\(content)\n</\(block.tag)>"
            }
            .joined(separator: "\n\n")
    }

    static func hasImage(_ context: DictationContext) -> Bool {
        context.screenshot != nil || context.clipboardImage != nil
    }

    static func visionImages(from context: DictationContext) -> [UserInput.Image] {
        if let screenshot = context.screenshot {
            dlog("[LLM] passing screenshot to vision model")
            return [.ciImage(CIImage(cgImage: screenshot))]
        }
        if let clipboardImage = context.clipboardImage {
            dlog("[LLM] passing clipboard image to vision model")
            return [.ciImage(CIImage(cgImage: clipboardImage))]
        }
        return []
    }

    // Edge case: Qwen-style models close reasoning with </think>, Gemma 4 with <channel|>.
    static func removingReasoningBlock(from result: String) -> String {
        let markers = ["</think>", "<channel|>"]
        guard let end = markers.compactMap({ result.range(of: $0, options: .backwards) })
            .max(by: { $0.upperBound < $1.upperBound })
        else {
            return result
        }
        return String(result[end.upperBound...])
    }

    static func drafterId(for modelId: String) -> String? {
        let name = modelId.lowercased()
        if name.contains("gemma-4-e4b") {
            return "mlx-community/gemma-4-E4B-it-qat-assistant-4bit"
        }
        if name.contains("gemma-4-e2b") {
            return "mlx-community/gemma-4-E2B-it-qat-assistant-4bit"
        }
        return nil
    }
}
