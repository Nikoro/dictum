@testable import Dictum
import Foundation
import Testing

struct WhisperModelStorageTests {
    private let modelId = "openai_whisper-large-v3_turbo"

    @Test
    func `downloads stay out of the Documents folder, whose access macOS ties to the signature`() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let downloadBase = WhisperModelStorage.standard.downloadBase.standardizedFileURL.path

        #expect(!downloadBase.hasPrefix(documents.standardizedFileURL.path))
        #expect(downloadBase.hasPrefix(LLMModelStorage.legacyRoot.standardizedFileURL.path))
    }

    @Test
    func `delete removes the folder WhisperKit downloaded the model into`() throws {
        let storage = try TemporaryWhisperStorage()
        defer { storage.remove() }
        let folder = try storage.placeModel(modelId)

        try storage.storage.delete(modelId)

        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test
    func `size on disk counts the downloaded model files`() throws {
        let storage = try TemporaryWhisperStorage()
        defer { storage.remove() }
        try storage.placeModel(modelId, bytes: 4096)

        #expect(storage.storage.sizeOnDisk(of: modelId) == 4096)
    }

    @Test
    func `migration moves models from the old Documents location`() throws {
        let storage = try TemporaryWhisperStorage()
        defer { storage.remove() }
        let legacyFolder = try storage.placeModel(modelId, in: storage.storage.legacyDownloadBase)

        let moved = storage.storage.migrateLegacyModels([modelId])

        #expect(moved == [modelId])
        #expect(!FileManager.default.fileExists(atPath: legacyFolder.path))
        #expect(storage.storage.sizeOnDisk(of: modelId) == 16)
    }

    @Test
    func `migration keeps a model already in the new location`() throws {
        let storage = try TemporaryWhisperStorage()
        defer { storage.remove() }
        try storage.placeModel(modelId, bytes: 64)
        let legacyFolder = try storage.placeModel(modelId, in: storage.storage.legacyDownloadBase)

        let moved = storage.storage.migrateLegacyModels([modelId])

        #expect(moved.isEmpty)
        #expect(storage.storage.sizeOnDisk(of: modelId) == 64)
        #expect(FileManager.default.fileExists(atPath: legacyFolder.path))
    }

    @Test
    func `migration skips models that were never downloaded`() throws {
        let storage = try TemporaryWhisperStorage()
        defer { storage.remove() }

        #expect(storage.storage.migrateLegacyModels([modelId]).isEmpty)
    }
}

struct TemporaryWhisperStorage {
    let root: URL
    let storage: WhisperModelStorage

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        storage = WhisperModelStorage(
            downloadBase: root.appendingPathComponent("whisperkit"),
            legacyDownloadBase: root.appendingPathComponent("Documents/huggingface")
        )
    }

    @discardableResult
    func placeModel(_ modelId: String, bytes: Int = 16, in downloadBase: URL? = nil) throws -> URL {
        let folder = (downloadBase ?? storage.downloadBase)
            .appendingPathComponent("models/argmaxinc/whisperkit-coreml/\(modelId)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(count: bytes).write(to: folder.appendingPathComponent("weight.bin"))
        return folder
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
