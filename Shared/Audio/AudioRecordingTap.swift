import AVFoundation

@MainActor
enum AudioRecordingTap {
    static func install(on node: AVAudioNode, format: AVAudioFormat?, sink: RecordingSink) {
        node.installTap(onBus: 0, bufferSize: 2048, format: format) { @Sendable [sink] buffer, _ in
            sink.write(buffer)
        }
    }
}
