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

    init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Dictum")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        self.path = logsDir.appendingPathComponent("dictum.log").path
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        self.handle = FileHandle(forWritingAtPath: path)
        self.handle?.seekToEndOfFile()
    }

    func log(_ message: String) {
        let line = "[\(Date())] \(message)\n"
        let data = Data(line.utf8)
        lock.lock()
        defer { lock.unlock() }
        if handle == nil {
            handle = FileHandle(forWritingAtPath: path)
            handle?.seekToEndOfFile()
        }
        handle?.write(data)
    }
}
