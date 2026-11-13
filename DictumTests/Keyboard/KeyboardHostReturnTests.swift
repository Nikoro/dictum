@testable import Dictum
import Foundation
import Testing

struct KeyboardHostReturnTests {
    @MainActor @Test func `automatic return waits for successful microphone activation`() async throws {
        let link = try #require(KeyboardActivationLink.url(host: "com.t3tools.t3code"))
        var steps: [String] = []
        await KeyboardHostReturn.perform(
            activation: link,
            activate: {
                steps.append("microphone ready")
                return true
            },
            open: { url in steps.append(url.absoluteString) }
        )
        #expect(steps == ["microphone ready", "t3code://"])
        steps.removeAll()
        await KeyboardHostReturn.perform(activation: link, activate: { false }, open: { url in
            steps.append(url.absoluteString)
        })
        #expect(steps.isEmpty)
    }

    @Test func `a new keyboard appearance retires evidence before a pid can be reused`() {
        var evidence = KeyboardHostEvidence()
        evidence.record(pid: 12, bundleID: "com.t3tools.t3code")
        #expect(evidence.bundleID(for: 12) == "com.t3tools.t3code")
        #expect(evidence.bundleID(for: 13) == nil)
        evidence.beginAppearance()
        #expect(evidence.bundleID(for: 12) == nil)
        evidence.record(pid: 12, bundleID: "com.apple.mobilenotes")
        #expect(evidence.bundleID(for: 12) == "com.apple.mobilenotes")
    }

    @Test func `activation returns only to a recognized host and rejects arbitrary callback urls`() throws {
        let link = try #require(KeyboardActivationLink.url(host: "com.t3tools.t3code"))
        #expect(KeyboardActivationLink.destination(from: link)?.absoluteString == "t3code://")
        for value in [
            "dictum://session?host=https://example.com",
            "dictum://session?host=unknown",
            "dictum://other?host=com.t3tools.t3code",
            "dictum://session?host=com.t3tools.t3code&host=com.apple.mobilenotes"
        ] {
            #expect(try KeyboardActivationLink.destination(from: #require(URL(string: value))) == nil)
        }
        #expect(KeyboardActivationLink.destination(host: "com.deepseek.chat") == nil)
    }
}
