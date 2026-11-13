struct KeyboardHostEvidence {
    private var current: [Int: String] = [:]

    mutating func beginAppearance() {
        current.removeAll(keepingCapacity: true)
    }

    mutating func record(pid: Int, bundleID: String) {
        guard pid > 0, !bundleID.isEmpty, bundleID.count < 256 else { return }
        if current.count >= 64, current[pid] == nil {
            current.removeAll(keepingCapacity: true)
        }
        current[pid] = bundleID
    }

    func bundleID(for pid: Int) -> String? {
        current[pid]
    }
}
