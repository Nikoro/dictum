#if DEBUG
import Darwin
import Foundation

@MainActor
enum SpeechBenchmark {
    struct Clip: Decodable {
        let id: String
        let path: String
    }

    struct Measurement: Codable {
        let id: String
        let pass: Int
        let seconds: Double
        let text: String
    }

    struct Report: Codable {
        let model: String
        let loadSeconds: Double
        let firstInferenceSeconds: Double
        let peakRSSBytes: Int64
        let measurements: [Measurement]
    }

    static func launchIfRequested() -> Bool {
        let arguments = CommandLine.arguments
        guard let manifest = option("--speech-benchmark", in: arguments) else { return false }
        let output = option("--output", in: arguments) ?? "/tmp/dictum-speech-benchmark.json"
        let model = option("--benchmark-model", in: arguments) ?? "openai_whisper-large-v3_turbo"
        Task {
            do {
                let clips = try JSONDecoder().decode([Clip].self, from: Data(contentsOf: URL(fileURLWithPath: manifest)))
                let report = try await run(
                    clips: clips,
                    model: model,
                    prepareOnly: arguments.contains("--benchmark-prepare-only")
                )
                try JSONEncoder().encode(report).write(to: URL(fileURLWithPath: output), options: .atomic)
                exit(0)
            } catch {
                let data = try? JSONEncoder().encode(["error": error.localizedDescription])
                try? data?.write(to: URL(fileURLWithPath: output), options: .atomic)
                exit(1)
            }
        }
        return true
    }

    private static func option(_ key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func run(clips: [Clip], model: String, prepareOnly: Bool) async throws -> Report {
        let variant = ParakeetVariant(rawValue: model)
        let loadStart = ContinuousClock.now
        if let variant {
            try await ParakeetEngine.shared.loadModel(variant: variant)
        } else {
            try await TranscriptionEngine.shared.loadModel(model)
        }
        let loadSeconds = elapsed(since: loadStart)
        let firstStart = ContinuousClock.now
        if let clip = clips.first {
            _ = try await transcribe(samples: FileAudioSource.loadMono16k(path: clip.path), variant: variant)
        }
        let firstSeconds = elapsed(since: firstStart)
        let measurements = prepareOnly ? [] : try await measure(clips: clips, variant: variant)
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Report(
            model: model,
            loadSeconds: loadSeconds,
            firstInferenceSeconds: firstSeconds,
            peakRSSBytes: Int64(usage.ru_maxrss),
            measurements: measurements
        )
    }

    private static func measure(clips: [Clip], variant: ParakeetVariant?) async throws -> [Measurement] {
        var measurements: [Measurement] = []
        for pass in 0 ..< 2 {
            for clip in clips {
                let samples = try FileAudioSource.loadMono16k(path: clip.path)
                let start = ContinuousClock.now
                let text = try await transcribe(samples: samples, variant: variant)
                measurements.append(Measurement(id: clip.id, pass: pass, seconds: elapsed(since: start), text: text))
            }
        }
        return measurements
    }

    private static func transcribe(samples: [Float], variant: ParakeetVariant?) async throws -> String {
        if let variant {
            return try await ParakeetEngine.shared.transcribe(audioSamples: samples, variant: variant, language: "pl")
        }
        return try await TranscriptionEngine.shared.transcribe(audioSamples: samples, language: "pl")
    }

    private static func elapsed(since start: ContinuousClock.Instant) -> Double {
        let parts = start.duration(to: .now).components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
#endif
