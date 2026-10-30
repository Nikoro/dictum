import AppKit

struct PasteboardSnapshot {
    private let items: [[(NSPasteboard.PasteboardType, Data)]]

    var isEmpty: Bool {
        items.isEmpty
    }

    init(of pasteboard: NSPasteboard) {
        items = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            }
        } ?? []
    }

    // Edge case: if the user copied something after `changeCount` was taken, putting the old
    // contents back would silently destroy their copy.
    func restore(to pasteboard: NSPasteboard, ifUnchangedSince changeCount: Int) {
        guard pasteboard.changeCount == changeCount else {
            dlog("[Paste] clipboard changed meanwhile, not restoring")
            return
        }
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map { representations in
            let item = NSPasteboardItem()
            for (type, data) in representations {
                item.setData(data, forType: type)
            }
            return item
        })
    }
}
