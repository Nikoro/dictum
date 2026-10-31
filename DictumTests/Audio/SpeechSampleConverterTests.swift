@testable import Dictum
import Foundation
import Testing

struct SpeechSampleConverterTests {
    @Test(arguments: [16000.0, 24000.0, 44100.0, 48000.0])
    func `device audio becomes 16 kHz without losing duration`(deviceRate: Double) throws {
        let converter = try SpeechSampleConverter(inputSampleRate: deviceRate)
        let oneSecond = (0 ..< Int(deviceRate)).map { Float(sin(Double($0) * 2 * .pi * 440 / deviceRate)) }

        var output: [Float] = []
        for chunk in stride(from: 0, to: oneSecond.count, by: 512) {
            output += converter.convert(Array(oneSecond[chunk ..< min(chunk + 512, oneSecond.count)]))
        }
        output += converter.flush()

        #expect(abs(output.count - 16000) <= 32)
    }
}
