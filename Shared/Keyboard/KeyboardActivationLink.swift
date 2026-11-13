import Foundation

enum KeyboardActivationLink {
    static func url(host: String?) -> URL? {
        var components = URLComponents(string: "dictum://session")
        if let host, destination(host: host) != nil {
            components?.queryItems = [URLQueryItem(name: "host", value: host)]
        }
        return components?.url
    }

    static func destination(from activation: URL) -> URL? {
        guard activation.scheme == "dictum", activation.host == "session",
              let query = URLComponents(url: activation, resolvingAgainstBaseURL: false)?.queryItems,
              query.filter({ $0.name == "host" }).count == 1,
              let host = query.first(where: { $0.name == "host" })?.value else { return nil }
        return destination(host: host)
    }

    static func destination(host: String) -> URL? {
        #if DEBUG
        if host == "com.dominikkrajcer.dictum.keyboardpreview" {
            return URL(string: "dictum-keyboard-preview://")
        }
        #endif
        return KeyboardHostCatalog.destination(host: host)
    }
}
