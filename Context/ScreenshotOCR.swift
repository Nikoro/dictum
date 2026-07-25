import Vision
import CoreGraphics

enum ScreenshotOCR {
    static let maxChars = 4000

    /// - Parameter languages: BCP-47 recognition languages, most likely first.
    static func extractText(from image: CGImage, languages: [String]) async -> String? {
        let start = Date()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        // Vision throws at perform time on an unsupported language, and the set of supported
        // languages is narrower than the list of languages Whisper can transcribe.
        let supported = Set((try? request.supportedRecognitionLanguages()) ?? [])
        let usable = languages.filter(supported.contains)
        if !usable.isEmpty {
            request.recognitionLanguages = usable
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            dlog("[OCR] failed: \(error.localizedDescription)")
            return nil
        }

        guard let observations = request.results, !observations.isEmpty else {
            return nil
        }

        // Vision uses bottom-left origin, normalized [0,1]. Sort top→bottom, left→right.
        let sorted = observations.sorted { lhs, rhs in
            let dy = rhs.boundingBox.minY - lhs.boundingBox.minY
            if abs(dy) > 0.01 { return dy < 0 }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }

        let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
        var joined = lines.joined(separator: "\n")
        if joined.count > maxChars {
            joined = String(joined.prefix(maxChars)) + "\n[...truncated]"
        }

        let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
        dlog("[OCR] \(joined.count) chars in \(elapsedMs)ms")

        return joined.isEmpty ? nil : joined
    }
}
