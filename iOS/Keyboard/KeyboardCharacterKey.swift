import SwiftUI
import UIKit

struct KeyboardCharacterKey: UIViewRepresentable {
    let character: String
    let uppercase: Bool
    let palette: KeyboardPalette
    let model: KeyboardModel
    let insert: (String) -> Void

    func makeUIView(context: Context) -> KeyboardAccentKeyControl {
        KeyboardAccentKeyControl()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: KeyboardAccentKeyControl, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 34, height: proposal.height ?? 43)
    }

    func updateUIView(_ control: KeyboardAccentKeyControl, context: Context) {
        control.configure(
            choices: KeyboardAlternates.choices(for: character, uppercase: uppercase),
            palette: palette,
            model: model,
            insert: insert
        )
    }

    static func dismantleUIView(_ control: KeyboardAccentKeyControl, coordinator: ()) {
        control.cancel()
    }
}

final class KeyboardAccentKeyControl: UIControl {
    let title = UILabel()
    let hintLabel = UILabel()
    let icon = UIImageView()
    let surface = UIView()
    var progress: UIActivityIndicatorView?
    var visualInsets = UIEdgeInsets.zero
    var tablet = false
    var hint = ""
    var iconEdge = 0
    var loweredIcon = false
    private let owner = UUID()
    private var choices: [String] = []
    private var insert: (String) -> Void = { _ in }
    private var tap: (() -> Void)?
    private weak var model: KeyboardModel?
    private var holdTask: Task<Void, Never>?
    private var holding = false
    private var activeTouch = false
    private var touchOrigin = CGPoint.zero
    private var trackedSymbol: String?
    private var normalColor = UIColor.clear
    private var pressedColor = UIColor.clear

    override init(frame: CGRect) {
        super.init(frame: frame)
        title.textAlignment = .center
        title.font = .systemFont(ofSize: 22)
        surface.isUserInteractionEnabled = false
        surface.layer.cornerRadius = 8
        addSubview(surface)
        addSubview(title)
        hintLabel.textAlignment = .center
        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.isUserInteractionEnabled = false
        icon.contentMode = .scaleAspectFit
        icon.isUserInteractionEnabled = false
        addSubview(hintLabel)
        addSubview(icon)
        layer.cornerRadius = 8
        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        choices: [String],
        palette: KeyboardPalette,
        model: KeyboardModel,
        tap: (() -> Void)? = nil,
        insert: @escaping (String) -> Void
    ) {
        self.model = model
        self.insert = insert
        self.tap = tap
        let changed = self.choices != choices
        self.choices = choices
        title.text = tap == nil ? choices.first : nil
        title.textColor = UIColor(palette.foreground)
        accessibilityLabel = tap == nil ? choices.first : String(localized: "ios.keyboard.emoji")
        normalColor = UIColor(palette.key)
        pressedColor = UIColor(palette.pressedKey)
        surface.backgroundColor = isHighlighted ? pressedColor : normalColor
        guard changed else { return }
        let alternatives = tap == nil ? Array(choices.dropFirst()) : choices
        accessibilityCustomActions = alternatives.map { symbol in
            UIAccessibilityCustomAction(name: symbol) { [weak self] _ in self?.insert(symbol); return true }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let key = bounds.inset(by: visualInsets)
        surface.frame = key
        title.frame = key.offsetBy(dx: 0, dy: tablet && !hint.isEmpty ? 8 : -4 / 3)
        hintLabel.frame = CGRect(x: key.minX, y: key.minY + 3, width: key.width, height: 17)
        let size: CGFloat = tablet ? 25 : 19
        icon.frame = CGRect(x: key.midX - size / 2, y: key.midY - size / 2, width: size, height: size)
        if icon.accessibilityIdentifier == "logo" {
            icon.frame = key
        } else if icon.accessibilityIdentifier == "recording" {
            icon.frame = CGRect(x: key.midX - 8, y: key.midY - 8, width: 16, height: 16)
        } else if tablet, loweredIcon {
            icon.frame.origin = CGPoint(x: iconEdge < 0 ? key.minX + 7 : key.maxX - size - 7, y: key.maxY - size - 5)
        }
        progress?.center = CGPoint(x: key.midX, y: key.midY)
    }

    func useFill(_ color: UIColor) {
        normalColor = color
        surface.backgroundColor = isHighlighted ? pressedColor : normalColor
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -12, dy: -12).contains(point)
    }

    override var isHighlighted: Bool {
        didSet { surface.backgroundColor = isHighlighted ? pressedColor : normalColor }
    }

    override func accessibilityActivate() -> Bool {
        UIDevice.current.playInputClick()
        activateTap()
        return true
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        UIDevice.current.playInputClick()
        activeTouch = true
        isHighlighted = true
        holding = false
        touchOrigin = touch.location(in: self)
        trackedSymbol = choices.first
        if choices.count > 1 {
            holdTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                guard let self, activeTouch, let model, model.keyboardFrame.width > 0 else { return }
                holding = true
                model.showAccents(KeyboardAccentSelection(
                    owner: owner,
                    choices: choices,
                    keyFrame: convert(bounds.inset(by: visualInsets), to: nil),
                    keyboardFrame: model.keyboardFrame,
                    emoji: tap != nil,
                    tablet: model.tabletLayout
                ))
            }
        }
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        if model?.accentPopup?.owner == owner {
            model?.accentPopup?.move(to: touch.location(in: nil))
        }
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        holdTask?.cancel()
        if let popup = model?.accentPopup, popup.owner == owner {
            insert(popup.selected)
        } else if !holding, let touch {
            let point = touch.location(in: self)
            if tablet, !hint.isEmpty, point.y - touchOrigin.y > 15, abs(point.x - touchOrigin.x) < 40 {
                insert(hint)
            } else if bounds.insetBy(dx: -10, dy: -12).contains(point) {
                if tap != nil {
                    activateTap()
                } else if let trackedSymbol {
                    insert(trackedSymbol)
                }
            }
        }
        cancel()
    }

    private func activateTap() {
        if let tap {
            tap()
        } else if let symbol = choices.first {
            insert(symbol)
        }
    }

    override func cancelTracking(with event: UIEvent?) {
        cancel()
    }

    func cancel() {
        holdTask?.cancel()
        holdTask = nil
        isHighlighted = false
        holding = false
        activeTouch = false
        model?.hideAccents(owner: owner)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            cancel()
        }
    }
}
