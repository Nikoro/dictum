import AppKit

enum MenuBarIcon {
    private static let iconSize = NSSize(width: 22, height: 22)
    private static let cornerRadius: CGFloat = 4.5

    private static let retinaScale: CGFloat = 2

    private static func makeRetinaBitmapContext(size: NSSize) -> CGContext? {
        let context = CGContext(
            data: nil,
            width: Int(size.width * retinaScale),
            height: Int(size.height * retinaScale),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.scaleBy(x: retinaScale, y: retinaScale)
        return context
    }

    private static func renderMicSymbol(
        pointSize: CGFloat,
        weight: NSFont.Weight
    ) -> (image: CGImage, alignmentOffset: CGPoint)? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        guard let mic = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }

        let micSize = mic.size
        let alignRect = mic.alignmentRect
        let offsetX = alignRect.midX - micSize.width / 2
        let offsetY = alignRect.midY - micSize.height / 2

        guard let bmp = makeRetinaBitmapContext(size: micSize) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: bmp, flipped: false)
        mic.draw(
            in: NSRect(origin: .zero, size: micSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let img = bmp.makeImage() else { return nil }
        return (img, CGPoint(x: offsetX, y: offsetY))
    }

    private static func drawRoundedRectWithMicCutout(
        in ctx: CGContext,
        size: NSSize,
        fillColor: CGColor
    ) {
        guard let offscreen = makeRetinaBitmapContext(size: size) else { return }

        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        offscreen.addPath(path)
        offscreen.setFillColor(fillColor)
        offscreen.fillPath()
        punchOutMic(from: offscreen, centeredIn: rect)

        if let composited = offscreen.makeImage() {
            ctx.draw(composited, in: CGRect(origin: .zero, size: size))
        }
    }

    private static func punchOutMic(from context: CGContext, centeredIn rect: CGRect) {
        guard let mic = renderMicSymbol(pointSize: 11, weight: .bold) else { return }
        let micWidth = CGFloat(mic.image.width) / retinaScale
        let micHeight = CGFloat(mic.image.height) / retinaScale
        let micRect = CGRect(
            x: rect.midX - micWidth / 2 - mic.alignmentOffset.x,
            y: rect.midY - micHeight / 2 - mic.alignmentOffset.y,
            width: micWidth,
            height: micHeight
        )
        context.setBlendMode(.destinationOut)
        context.draw(mic.image, in: micRect)
    }

    static func microphone() -> NSImage {
        let image = NSImage(size: iconSize, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            drawRoundedRectWithMicCutout(in: ctx, size: iconSize, fillColor: NSColor.black.cgColor)
            return true
        }
        image.isTemplate = true
        return image
    }

    static func recording() -> NSImage {
        let image = NSImage(size: iconSize, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            drawRoundedRectWithMicCutout(in: ctx, size: iconSize, fillColor: NSColor.white.cgColor)

            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: NSRect(x: 12, y: 12, width: 5, height: 5)).fill()

            return true
        }
        image.isTemplate = false
        return image
    }
}
