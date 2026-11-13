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
        await KeyboardHostReturn.perform(
            activation: link,
            activate: { false },
            open: { url in
                steps.append(url.absoluteString)
            }
        )
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

    @MainActor @Test func `a cancelled return never activates the microphone`() async throws {
        let link = try #require(KeyboardActivationLink.url(host: "com.t3tools.t3code"))
        var activated = false
        var opened = false
        let task = Task {
            await KeyboardHostReturn.perform(
                activation: link,
                activate: { activated = true; return true },
                open: { _ in opened = true }
            )
        }
        task.cancel()
        await task.value
        #expect(!activated)
        #expect(!opened)
    }

    @MainActor @Test func `delayed foreground activation waits before enabling the microphone`() async throws {
        let link = try #require(KeyboardActivationLink.url(host: "com.t3tools.t3code"))
        var foreground = false
        var steps: [String] = []
        await KeyboardHostReturn.perform(
            activation: link,
            isForeground: { foreground },
            wait: { _ in steps.append("scene became active"); foreground = true },
            activate: { steps.append("microphone ready"); return true },
            open: { _ in steps.append("returned") }
        )
        #expect(steps == ["scene became active", "microphone ready", "returned"])
    }

    @MainActor @Test func `a permission transition waits again and rechecks microphone readiness`() async throws {
        let link = try #require(KeyboardActivationLink.url(host: "com.t3tools.t3code"))
        var foreground = true
        var ready = true
        var opened = false
        await KeyboardHostReturn.perform(
            activation: link,
            isForeground: { foreground },
            isReady: { ready },
            wait: { _ in foreground = true; ready = false },
            activate: { foreground = false; return true },
            open: { _ in opened = true }
        )
        #expect(!opened)
    }

    @MainActor @Test func `a foreground transition after activation still returns exactly once`() async throws {
        let link = try #require(KeyboardActivationLink.url(host: "com.t3tools.t3code"))
        var foreground = true
        var opened = 0
        await KeyboardHostReturn.perform(
            activation: link,
            isForeground: { foreground },
            wait: { _ in foreground = true },
            activate: { foreground = false; return true },
            open: { _ in opened += 1 }
        )
        #expect(opened == 1)
    }

    @MainActor @Test func `a scene that never activates times out without opening audio or a host`() async throws {
        let link = try #require(KeyboardActivationLink.url(host: "com.t3tools.t3code"))
        var polls = 0
        var activated = false
        var opened = false
        await KeyboardHostReturn.perform(
            activation: link,
            isForeground: { false },
            wait: { _ in polls += 1 },
            activate: { activated = true; return true },
            open: { _ in opened = true }
        )
        #expect(polls == 100)
        #expect(!activated)
        #expect(!opened)
    }
}
