#if DEBUG
import AVFoundation

// Edge case: debug-only entry point, so the STT path can be verified without a microphone.
// `Dictum --transcribe-file a.wav --output out.txt [--language pl|auto] [--cleanup [--clipboard text]]`.
@MainActor
enum DebugTranscriptionHarness {
    static func runIfRequested() {
        let arguments = CommandLine.arguments
        let outputPath = arguments.firstIndex(of: "--output").map { arguments[$0 + 1] } ?? "/dev/stdout"
        if arguments.contains("--llm-bench") {
            let drafter = arguments.firstIndex(of: "--drafter").map { arguments[$0 + 1] }
            Task {
                let report = await LLMBenchmark.run(drafterId: drafter)
                try? report.write(toFile: outputPath, atomically: true, encoding: .utf8)
                exit(0)
            }
            return
        }
        guard let fileIndex = arguments.firstIndex(of: "--transcribe-file"), fileIndex + 1 < arguments.count else {
            return
        }
        let languageArgument = arguments.firstIndex(of: "--language").map { arguments[$0 + 1] }
        let language = languageArgument == "auto" ? nil : (languageArgument ?? "pl")
        Task {
            var report = arguments.contains("parakeet")
                ? await runParakeet(path: arguments[fileIndex + 1])
                : await run(path: arguments[fileIndex + 1], language: language)
            if arguments.contains("--cleanup") {
                let clipboard = arguments.firstIndex(of: "--clipboard").map { arguments[$0 + 1] }
                report += await cleanUp(report, clipboard: clipboard)
            }
            try? report.write(toFile: outputPath, atomically: true, encoding: .utf8)
            exit(0)
        }
    }

    private static func cleanUp(_ report: String, clipboard: String?) async -> String {
        let transcript = report.components(separatedBy: "text=").last?.trimmingCharacters(in: .newlines) ?? ""
        let context = clipboard.map {
            DictationContext(
                appName: "Notes",
                selectedText: nil,
                screenshot: nil,
                ocrText: nil,
                clipboardText: $0,
                clipboardImage: nil
            )
        }
        do {
            try await ModelWarmupCoordinator.shared.loadLLMModelIfNeeded()
            let start = ContinuousClock.now
            let cleaned = try await LLMProcessor.shared.cleanText(
                rawText: transcript,
                prompt: AppSettings.shared.resolvePrompt(for: nil),
                context: context
            )
            return "llm=\(ContinuousClock.now - start)\ncleaned=\(cleaned)\n"
        } catch {
            return "llmError=\(error)\n"
        }
    }

    private static func runParakeet(path: String) async -> String {
        do {
            let samples = try FileAudioSource.loadMono16k(path: path)
            try await ParakeetEngine.shared.loadModel()
            let start = ContinuousClock.now
            let text = try await ParakeetEngine.shared.transcribe(audioSamples: SpeechTrimmer.speechOnly(samples) ?? [])
            return "audio=\(samples.count / 16000)s afterKeyUp=\(ContinuousClock.now - start)\ntext=\(text)\n"
        } catch {
            return "error=\(error)\n"
        }
    }

    private static func run(path: String, language: String?) async -> String {
        do {
            let samples = try FileAudioSource.loadMono16k(path: path)
            let source = FileAudioSource(samples: samples)
            try await ModelWarmupCoordinator.shared.loadSTTModelIfNeeded()
            let transcriber = LiveChunkTranscriber(audioSource: source, language: language) { false }
            transcriber.start()
            try await Task.sleep(for: .seconds(Double(samples.count) / 16000))
            let keyUp = ContinuousClock.now
            let text = try await transcriber.finish(allSamples: samples)
            return "audio=\(samples.count / 16000)s afterKeyUp=\(ContinuousClock.now - keyUp)\ntext=\(text)\n"
        } catch {
            return "error=\(error)\n"
        }
    }
}

final class FileAudioSource: CapturedAudioSource {
    private let samples: [Float]
    private let startedAt = Date()

    init(samples: [Float]) {
        self.samples = samples
    }

    var capturedSampleCount: Int {
        min(samples.count, Int(Date().timeIntervalSince(startedAt) * 16000))
    }

    func capturedSamples(in range: Range<Int>) -> [Float] {
        Array(samples[range.clamped(to: 0 ..< samples.count)])
    }

    static func loadMono16k(path: String) throws -> [Float] {
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
        let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)
        guard let target, let converter = AVAudioConverter(from: file.processingFormat, to: target),
              let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
        else {
            return []
        }
        try file.read(into: input)
        let ratio = 16000 / file.processingFormat.sampleRate
        guard let output = AVAudioPCMBuffer(
            pcmFormat: target,
            frameCapacity: AVAudioFrameCount(Double(input.frameLength) * ratio) + 1024
        ) else {
            return []
        }
        nonisolated(unsafe) var consumed = false
        converter.convert(to: output, error: nil) { _, status in
            status.pointee = consumed ? .endOfStream : .haveData
            defer { consumed = true }
            return consumed ? nil : input
        }
        guard let channel = output.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }
}
#endif
