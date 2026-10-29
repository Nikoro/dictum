import AppKit

struct PasteboardSnapshot {
    private let items: [(NSPasteboard.PasteboardType, Data)]

    var isEmpty: Bool {
        items.isEmpty
    }

    init(of pasteboard: NSPasteboard) {
        items = pasteboard.pasteboardItems?.flatMap { item in
            item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            }
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        for (type, data) in items {
            pasteboard.setData(data, forType: type)
        }
    }
}
