@testable import Dictum
import Foundation
import Testing

struct KeyboardHostCatalogTests {
    @Test(arguments: [
        ("com.anthropic.claude", "claude://"),
        ("com.google.gemini", "gemini-app://"),
        ("com.google.Gmail", "googlegmail://"),
        ("org.whispersystems.signal", "sgnl://"),
        ("com.facebook.Messenger", "fb-messenger://"),
        ("com.telegram.telegram-ios", "tg://"),
        ("ph.telegra.Telegraph", "tg://")
    ])
    func `requested hosts survive the keyboard activation round trip`(bundleID: String, destination: String) throws {
        let activation = try #require(KeyboardActivationLink.url(host: bundleID))
        let query = URLComponents(url: activation, resolvingAgainstBaseURL: false)?.queryItems
        #expect(query == [URLQueryItem(name: "host", value: bundleID)])
        #expect(KeyboardActivationLink.destination(from: activation)?.absoluteString == destination)
    }

    @Test(arguments: [
        "org.whispersystems.signal.shareextension",
        "com.facebook.Messenger.fake",
        "com.google.gemini.attacker",
        "com.google.Gmail.ShareExtension",
        "COM.GOOGLE.GMAIL"
    ])
    func `similar identifiers never substitute for the host`(bundleID: String) throws {
        let activation = try #require(KeyboardActivationLink.url(host: bundleID))
        #expect(URLComponents(url: activation, resolvingAgainstBaseURL: false)?.queryItems == nil)
        #expect(KeyboardActivationLink.destination(from: activation) == nil)
    }

    @Test func `messaging variants keep separate app schemes`() {
        #expect(KeyboardActivationLink.destination(host: "net.whatsapp.WhatsApp")?.scheme == "whatsapp-consumer")
        #expect(KeyboardActivationLink.destination(host: "net.whatsapp.WhatsAppSMB")?.scheme == "whatsapp")
        #expect(KeyboardActivationLink.destination(host: "app.swiftgram.ios")?.scheme == "sg")
        #expect(KeyboardActivationLink.destination(host: "app.nicegram")?.scheme == "nicegram")
        #expect(KeyboardActivationLink.destination(host: "com.apple.MobileSMS")?.scheme == "ichat")
    }
}
