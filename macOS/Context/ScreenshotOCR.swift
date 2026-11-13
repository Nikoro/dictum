import CoreGraphics
import Vision

enum ScreenshotOCR {
    static let maxChars = 4000

    static func extractText(from image: CGImage, languagesMostLikelyFirst languages: [String]) -> String? {
        let start = Date()
        let request = makeRequest(languages: languages)

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

        let lines = readingOrder(observations).compactMap { $0.topCandidates(1).first?.string }
        var joined = lines.joined(separator: "\n")
        if joined.count > maxChars {
            joined = String(joined.prefix(maxChars)) + "\n[...truncated]"
        }

        let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
        dlog("[OCR] \(joined.count) chars in \(elapsedMs)ms")

        return joined.isEmpty ? nil : joined
    }

    private static func makeRequest(languages: [String]) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let supported = Set((try? request.supportedRecognitionLanguages()) ?? [])
        let usable = languages.filter(supported.contains)
        if !usable.isEmpty {
            request.recognitionLanguages = usable
        }
        return request
    }

    // Edge case: Vision boxes use a bottom-left origin, so top-to-bottom means descending minY.
    private static func readingOrder(_ observations: [VNRecognizedTextObservation]) -> [VNRecognizedTextObservation] {
        observations.sorted { lhs, rhs in
            let verticalDelta = rhs.boundingBox.minY - lhs.boundingBox.minY
            if abs(verticalDelta) > 0.01 {
                return verticalDelta < 0
            }
            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
    }
}
