import UIKit

extension KeyboardAccentKeyControl {
    func configureDecoration(hint: String, tablet: Bool) {
        iconEdge = 0
        loweredIcon = false
        self.hint = hint
        self.tablet = tablet
        hintLabel.text = hint
        hintLabel.textColor = title.textColor.withAlphaComponent(0.35)
        icon.image = nil
        icon.accessibilityIdentifier = nil
        title.font = .systemFont(ofSize: 22)
        setNeedsLayout()
    }

    func configureAction(_ appearance: KeyboardActionAppearance, palette: KeyboardPalette) {
        hint = ""
        hintLabel.text = nil
        title.text = appearance.title
        title.font = .systemFont(ofSize: 19)
        accessibilityLabel = appearance.label
        accessibilityTraits = appearance.selected ? [.keyboardKey, .selected] : .keyboardKey
        icon.tintColor = appearance.recording ? .systemRed : UIColor(palette.foreground)
        icon.accessibilityIdentifier = appearance.purple ? "logo" : appearance.recording ? "recording" : nil
        icon.image = Self.actionImage(for: appearance)
        icon.contentMode = appearance.purple ? .scaleAspectFill : .scaleAspectFit
        icon.clipsToBounds = true
        icon.layer.cornerRadius = appearance.purple ? 8 : 0
        isEnabled = appearance.enabled
        icon.alpha = appearance.enabled ? 1 : 0.35
        useFill(UIColor(appearance.modifier ? palette.modifier : palette.key))
        configureProgress(appearance.busy, palette: palette)
        setNeedsLayout()
    }

    private static func actionImage(for appearance: KeyboardActionAppearance) -> UIImage? {
        if appearance.recording {
            stopImage
        } else if let asset = appearance.asset {
            UIImage(named: asset)?.withRenderingMode(appearance.purple ? .alwaysOriginal : .alwaysTemplate)
        } else if let symbol = appearance.symbol {
            UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22))
        } else {
            nil
        }
    }

    private func configureProgress(_ visible: Bool, palette: KeyboardPalette) {
        if visible, progress == nil {
            let indicator = UIActivityIndicatorView(style: .medium)
            addSubview(indicator)
            progress = indicator
        }
        progress?.color = UIColor(palette.foreground)
        if visible {
            progress?.startAnimating()
        } else {
            progress?.stopAnimating()
        }
    }

    private static let stopImage = UIGraphicsImageRenderer(size: CGSize(width: 19, height: 16)).image { _ in
        UIColor.white.setFill()
        UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 19, height: 16), cornerRadius: 4).fill()
    }.withRenderingMode(.alwaysTemplate)
}
