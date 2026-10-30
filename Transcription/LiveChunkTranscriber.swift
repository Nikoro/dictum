import Foundation

protocol CapturedAudioSource: AnyObject {
    var capturedSampleCount: Int { get }
    func capturedSamples(in range: Range<Int>) -> [Float]
}

@MainActor
final class LiveChunkTranscriber {
    private static let sampleRate = 16000
    private static let pollInterval: Duration = .seconds(1)
    private static let minimumChunkSeconds = 8
    private static let forcedCutSeconds = 28
    private static let pauseSeconds = 0.3

    private let audioSource: any CapturedAudioSource
    private let language: String?
    private let isAborted: @MainActor () -> Bool
    private var committedSampleCount = 0
    private var transcribedChunks: [String] = []
    private var loopTask: Task<Void, Never>?
    private var isFinishing = false

    init(audioSource: any CapturedAudioSource, language: String?, isAborted: @escaping @MainActor () -> Bool) {
        self.audioSource = audioSource
        self.language = language
        self.isAborted = isAborted
    }

    func start() {
        loopTask = Task { [weak self] in
            while let self, !isFinishing, !isAborted(), !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                await transcribeNextChunkIfReady()
            }
        }
    }

    func cancel() {
        loopTask?.cancel()
        loopTask = nil
    }

    func finish(allSamples: [Float]) async throws -> String {
        isFinishing = true
        await loopTask?.value
        let remainder = Array(allSamples[min(committedSampleCount, allSamples.count)...])
        if let text = try await transcribe(remainder) {
            transcribedChunks.append(text)
        }
        return transcribedChunks.joined(separator: " ")
    }

    private func transcribeNextChunkIfReady() async {
        let available = audioSource.capturedSampleCount
        let pending = audioSource.capturedSamples(in: committedSampleCount ..< available)
        guard let cut = Self.chunkCut(in: pending) else { return }
        let chunk = Array(pending[..<cut])
        committedSampleCount += cut
        do {
            if let text = try await transcribe(chunk) {
                transcribedChunks.append(text)
            }
        } catch {
            dlog("[STT] live chunk failed: \(error)")
        }
    }

    private func transcribe(_ samples: [Float]) async throws -> String? {
        guard !isAborted(), let speech = SpeechTrimmer.speechOnly(samples) else { return nil }
        try await ModelWarmupCoordinator.shared.loadSTTModelIfNeeded()
        let signpost = DictumSignposts.pipeline.beginInterval("ChunkTranscription")
        defer { DictumSignposts.pipeline.endInterval("ChunkTranscription", signpost) }
        let start = ContinuousClock.now
        let text = ModelWarmupCoordinator.shared.activeSpeechEngine == .parakeet
            ? try await ParakeetEngine.shared.transcribe(audioSamples: speech)
            : try await TranscriptionEngine.shared.transcribe(
                audioSamples: speech,
                language: language,
                precedingText: transcribedChunks.last
            )
        dlog("[STT] chunk: \(samples.count / Self.sampleRate)s audio → \(text.count) chars in \(ContinuousClock.now - start)")
        return text.isEmpty ? nil : text
    }

    // Edge case: cutting mid-word garbles both halves, so a chunk ends in the last pause after
    // the minimum length; only a pause-free stretch is cut hard, below Whisper's 30 s window.
    private static func chunkCut(in pending: [Float]) -> Int? {
        let minimum = minimumChunkSeconds * sampleRate
        let forced = forcedCutSeconds * sampleRate
        guard pending.count >= minimum else { return nil }
        let searchable = Array(pending[..<min(pending.count, forced)])
        if let pause = lastPauseEnd(in: searchable, notBefore: minimum) {
            return pause
        }
        return pending.count >= forced ? forced : nil
    }

    private static func lastPauseEnd(in samples: [Float], notBefore minimum: Int) -> Int? {
        let levels = SpeechTrimmer.frameLevels(samples)
        let threshold = SpeechTrimmer.speechThreshold(levels)
        let frameLength = SpeechTrimmer.frameLength
        let framesPerPause = Int(pauseSeconds * Double(sampleRate)) / frameLength
        var quietRun = 0
        for index in levels.indices.reversed() {
            quietRun = levels[index] <= threshold ? quietRun + 1 : 0
            let pauseMiddle = (index + framesPerPause / 2) * frameLength
            if quietRun >= framesPerPause, pauseMiddle >= minimum {
                return pauseMiddle
            }
        }
        return nil
    }
}
