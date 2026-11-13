import AppKit
import Foundation
import os

private let _logger = DictumLogger()

func dlog(_ message: String) {
    _logger.log(message)
}

enum DictumSignposts {
    static let pipeline = OSSignposter(subsystem: DictumLogger.subsystem, category: "pipeline")
}

private final class DictumLogger: @unchecked Sendable {
    static let subsystem = "com.dominikkrajcer.dictum"
    private var systemLoggers: [String: Logger] = [:]

    private let queue = DispatchQueue(label: "com.dominikkrajcer.dictum.logger", qos: .utility)
    private var handle: FileHandle?
    private let path: String
    private let backupPath: String
    private let maxBytes: UInt64 = 1_000_000
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Dictum")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        path = logsDir.appendingPathComponent("dictum.log").path
        backupPath = logsDir.appendingPathComponent("dictum.log.bak").path
        ensureFileExists()
        handle = FileHandle(forWritingAtPath: path)
        handle?.seekToEndOfFile()
    }

    deinit {
        try? handle?.close()
    }

    func log(_ message: String) {
        let timestamp = Date()
        queue.async { [self] in
            let data = Data("[\(dateFormatter.string(from: timestamp))] \(message)\n".utf8)
            rotateIfNeeded()
            if handle == nil {
                ensureFileExists()
                handle = FileHandle(forWritingAtPath: path)
                handle?.seekToEndOfFile()
            }
            handle?.write(data)
            systemLogger(for: message).log("\(message, privacy: .public)")
        }
    }

    private func systemLogger(for message: String) -> Logger {
        let category = message.hasPrefix("[")
            ? String(message.dropFirst().prefix { $0 != "]" })
            : "general"
        if let logger = systemLoggers[category] {
            return logger
        }
        let logger = Logger(subsystem: Self.subsystem, category: category)
        systemLoggers[category] = logger
        return logger
    }

    private func ensureFileExists() {
        let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil, attributes: attributes)
        } else {
            try? FileManager.default.setAttributes(attributes, ofItemAtPath: path)
        }
    }

    private func rotateIfNeeded() {
        guard let handle else { return }
        let size = (try? handle.offset()) ?? 0
        guard size >= maxBytes else { return }
        try? handle.close()
        self.handle = nil
        try? FileManager.default.removeItem(atPath: backupPath)
        try? FileManager.default.moveItem(atPath: path, toPath: backupPath)
        ensureFileExists()
        self.handle = FileHandle(forWritingAtPath: path)
        self.handle?.seekToEndOfFile()
    }
}
