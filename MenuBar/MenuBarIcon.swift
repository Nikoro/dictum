import AppKit

enum MenuBarIcon {

    private static let iconSize = NSSize(width: 22, height: 22)
    private static let cornerRadius: CGFloat = 4.5

    /// Renders SF Symbol mic.fill to a CGImage, returning both the image
    /// and the alignment rect offset so callers can center on visual content.
    private static func micCGImage(pointSize: CGFloat, weight: NSFont.Weight) -> (image: CGImage, alignmentOffset: CGPoint)? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        guard let mic = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }

        let micSize = mic.size
        let alignRect = mic.alignmentRect
        // Offset from full image center to alignment rect center
        let offsetX = alignRect.midX - micSize.width / 2
        let offsetY = alignRect.midY - micSize.height / 2

        let scale: CGFloat = 2
        let w = Int(micSize.width * scale)
        let h = Int(micSize.height * scale)

        guard let bmp = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        bmp.scaleBy(x: scale, y: scale)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: bmp, flipped: false)
        mic.draw(in: NSRect(origin: .zero, size: micSize),
                 from: .zero, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        guard let img = bmp.makeImage() else { return nil }
        return (img, CGPoint(x: offsetX, y: offsetY))
    }

    /// Renders rounded rect with mic.fill punched out as transparency.
    private static func drawRoundedRectWithMicCutout(
        in ctx: CGContext,
        size: NSSize,
        fillColor: CGColor
    ) {
        let scale: CGFloat = 2
        let w = Int(size.width * scale)
        let h = Int(size.height * scale)

        guard let offscreen = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        offscreen.scaleBy(x: scale, y: scale)

        // 1. Fill rounded rectangle
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        offscreen.addPath(path)
        offscreen.setFillColor(fillColor)
        offscreen.fillPath()

        // 2. Punch out mic using destinationOut on CGImage (not NSImage.draw)
        if let mic = micCGImage(pointSize: 11, weight: .bold) {
            let micW = CGFloat(mic.image.width) / scale
            let micH = CGFloat(mic.image.height) / scale
            // Center alignment rect (not full image) within rounded rect
            let micRect = CGRect(
                x: rect.midX - micW / 2 - mic.alignmentOffset.x,
                y: rect.midY - micH / 2 - mic.alignmentOffset.y,
                width: micW,
                height: micH
            )
            offscreen.setBlendMode(.destinationOut)
            offscreen.draw(mic.image, in: micRect)
        }

        // 3. Composite onto main context
        if let composited = offscreen.makeImage() {
            ctx.draw(composited, in: CGRect(origin: .zero, size: size))
        }
    }

    /// Rounded rectangle with mic cutout (template — adapts to light/dark).
    static func microphone(state: AppState) -> NSImage {
        let image = NSImage(size: iconSize, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            drawRoundedRectWithMicCutout(in: ctx, size: iconSize, fillColor: NSColor.black.cgColor)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Recording icon — rounded rect with mic cutout + red REC dot.
    static func recording() -> NSImage {
        let image = NSImage(size: iconSize, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            drawRoundedRectWithMicCutout(in: ctx, size: iconSize, fillColor: NSColor.white.cgColor)

            // Red dot (rec indicator)
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: NSRect(x: 12, y: 12, width: 5, height: 5)).fill()

            return true
        }
        image.isTemplate = false
        return image
    }
}
