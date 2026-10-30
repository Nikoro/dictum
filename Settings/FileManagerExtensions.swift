import Foundation

extension FileManager {
    // Edge case: Hugging Face cache snapshots are symlinks into blobs/; counting them as well
    // would report every model at twice its size.
    func directorySize(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isSymbolicLinkKey]
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: Array(keys)) else { return 0 }
        var total: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            guard let values = try? fileURL.resourceValues(forKeys: keys), values.isSymbolicLink != true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
