import AppKit

enum MenuBarIcon {

    /// Tworzy ikonę mikrofonu z falami dźwiękowymi dla menu bar (18x18 pt, template).
    static func microphone(state: AppState) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSColor.black.setStroke()

            // -- Mikrofon (korpus) --
            let micBody = NSBezierPath(
                roundedRect: NSRect(x: 6, y: 7, width: 6, height: 9),
                xRadius: 3,
                yRadius: 3
            )
            micBody.fill()

            // -- Uchwyt (łuk pod mikrofonem) --
            let arc = NSBezierPath()
            arc.lineWidth = 1.4
            arc.appendArc(
                withCenter: NSPoint(x: 9, y: 7),
                radius: 5.5,
                startAngle: 180,
                endAngle: 0,
                clockwise: true
            )
            arc.stroke()

            // -- Nóżka --
            let stem = NSBezierPath()
            stem.lineWidth = 1.4
            stem.move(to: NSPoint(x: 9, y: 1.5))
            stem.line(to: NSPoint(x: 9, y: 4))
            stem.stroke()

            // -- Podstawka --
            let base = NSBezierPath()
            base.lineWidth = 1.4
            base.move(to: NSPoint(x: 6.5, y: 1.5))
            base.line(to: NSPoint(x: 11.5, y: 1.5))
            base.stroke()

            return true
        }

        image.isTemplate = true
        return image
    }

    /// Ikona nagrywania — mikrofon z czerwoną kropką.
    /// Nie jest template (kolorowa).
    static func recording() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // Rysujemy mikrofon
            NSColor.white.setFill()
            NSColor.white.setStroke()

            let micBody = NSBezierPath(
                roundedRect: NSRect(x: 6, y: 7, width: 6, height: 9),
                xRadius: 3,
                yRadius: 3
            )
            micBody.fill()

            let arc = NSBezierPath()
            arc.lineWidth = 1.4
            arc.appendArc(
                withCenter: NSPoint(x: 9, y: 7),
                radius: 5.5,
                startAngle: 180,
                endAngle: 0,
                clockwise: true
            )
            arc.stroke()

            let stem = NSBezierPath()
            stem.lineWidth = 1.4
            stem.move(to: NSPoint(x: 9, y: 1.5))
            stem.line(to: NSPoint(x: 9, y: 4))
            stem.stroke()

            let base = NSBezierPath()
            base.lineWidth = 1.4
            base.move(to: NSPoint(x: 6.5, y: 1.5))
            base.line(to: NSPoint(x: 11.5, y: 1.5))
            base.stroke()

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
