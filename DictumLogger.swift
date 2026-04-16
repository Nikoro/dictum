import AppKit
import Foundation

private let _logger = DictumLogger()

func dlog(_ message: String) {
    _logger.log(message)
}

private final class DictumLogger: @unchecked Sendable {
    private let lock = NSLock()
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
        self.path = logsDir.appendingPathComponent("dictum.log").path
        self.backupPath = logsDir.appendingPathComponent("dictum.log.bak").path
        ensureFileExists()
        self.handle = FileHandle(forWritingAtPath: path)
        self.handle?.seekToEndOfFile()
    }

    deinit {
        try? handle?.close()
    }

    func log(_ message: String) {
        let line = "[\(dateFormatter.string(from: Date()))] \(message)\n"
        let data = Data(line.utf8)
        lock.lock()
        defer { lock.unlock() }
        rotateIfNeeded()
        if handle == nil {
            ensureFileExists()
            handle = FileHandle(forWritingAtPath: path)
            handle?.seekToEndOfFile()
        }
        handle?.write(data)
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
