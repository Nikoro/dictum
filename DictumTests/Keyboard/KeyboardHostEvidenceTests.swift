@testable import Dictum
import Foundation
import Testing

struct KeyboardHostEvidenceTests {
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

    @Test func `implausible evidence is ignored and a full table starts over`() {
        var evidence = KeyboardHostEvidence()
        evidence.record(pid: 0, bundleID: "com.apple.mobilenotes")
        evidence.record(pid: 5, bundleID: "")
        evidence.record(pid: 6, bundleID: String(repeating: "a", count: 256))
        #expect(evidence.bundleID(for: 0) == nil)
        #expect(evidence.bundleID(for: 5) == nil)
        #expect(evidence.bundleID(for: 6) == nil)
        for pid in 1 ... 64 {
            evidence.record(pid: pid, bundleID: "host.\(pid)")
        }
        evidence.record(pid: 64, bundleID: "host.updated")
        #expect(evidence.bundleID(for: 1) == "host.1")
        evidence.record(pid: 65, bundleID: "host.65")
        #expect(evidence.bundleID(for: 1) == nil)
        #expect(evidence.bundleID(for: 65) == "host.65")
    }
}
