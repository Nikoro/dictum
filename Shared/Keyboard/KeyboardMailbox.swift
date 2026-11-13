import Foundation

struct KeyboardMailbox: Sendable {
    static let appGroup = "group.com.dominikkrajcer.dictum"
    let directory: URL

    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
    }

    func readSession() throws -> KeyboardSession? {
        let url = directory.appendingPathComponent("session.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(KeyboardSession.self, from: Data(contentsOf: url))
    }

    func publish(_ session: KeyboardSession) throws {
        try write(session, to: directory.appendingPathComponent("session.json"))
    }

    func send(_ command: KeyboardCommand) throws {
        try write(command, to: directory.appendingPathComponent(command.id.uuidString + ".command"))
    }

    func takeCommands() throws -> [KeyboardCommand] {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "command" }
        return urls.compactMap { url in
            defer { try? FileManager.default.removeItem(at: url) }
            return try? JSONDecoder().decode(KeyboardCommand.self, from: Data(contentsOf: url))
        }.sorted { $0.createdAt < $1.createdAt }
    }

    func clear() throws {
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func write(_ value: some Encodable, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
    }
}
