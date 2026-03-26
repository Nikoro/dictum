import AppKit

enum MenuBarIcon {

    /// SF Symbol mikrofonu dla menu bar (template — dopasowuje się do light/dark).
    static func microphone(state: AppState) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Dictum")?
            .withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = true
        return image
    }

    /// Ikona nagrywania — mikrofon z czerwoną kropką REC.
    /// Nie jest template (kolorowa).
    static func recording() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Rysujemy mic.fill jako SF Symbol
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            if let mic = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                NSColor.white.set()
                let micRect = NSRect(x: 1, y: 2, width: 14, height: 16)
                mic.draw(in: micRect)
            }

            // Czerwona kropka (rec indicator)
            NSColor.systemRed.setFill()
            let dot = NSBezierPath(
                ovalIn: NSRect(x: 12, y: 12, width: 5, height: 5)
            )
            dot.fill()

            return true
        }

        image.isTemplate = false
        return image
    }
}
