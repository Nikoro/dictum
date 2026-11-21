@testable import Dictum
import Foundation
import Testing

struct KeyboardActivationLinkTests {
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
