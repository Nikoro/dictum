@testable import Dictum
import Foundation
import Testing

struct TestFlightExportTests {
    @Test func `mailbox and signing entitlements use the chosen shared group`() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("iOS/Resources/Dictum.entitlements"))
        let entitlements = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(KeyboardMailbox.appGroup == "group.com.dominikkrajcer.dictum")
        #expect(entitlements["com.apple.security.application-groups"] as? [String] == [KeyboardMailbox.appGroup])
    }

    @Test func `export signs both bundles locally and stays internal`() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("iOS/Resources/TestFlightExportOptions.plist")
        let data = try Data(contentsOf: file)
        let options = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(options["method"] as? String == "app-store-connect")
        #expect(options["signingStyle"] as? String == "manual")
        #expect(options["signingCertificate"] as? String == "Apple Distribution")
        #expect(options["testFlightInternalTestingOnly"] as? Bool == true)
        #expect(options["destination"] as? String == "export")
        #expect(options["manageAppVersionAndBuildNumber"] as? Bool == false)
        let profiles = try #require(options["provisioningProfiles"] as? [String: String])
        #expect(profiles["com.dominikkrajcer.dictum"] == "Dictum Unified App Store")
        #expect(profiles["com.dominikkrajcer.dictum.keyboard"] == "Dictum Unified Keyboard App Store")
    }

    @Test func `version preparation follows the BirthMinder date counter policy`() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [root.appendingPathComponent("DictumTests/Distribution/test_version.py").path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
}
