import SwiftUI
import UIKit

@MainActor
final class KeyboardViewController: UIInputViewController {
    private let model = KeyboardModel()
    private let hostResolver = KeyboardHostResolver()
    private let plane = KeyboardPlaneView()
    private weak var hostedView: UIView?
    private var pollingTask: Task<Void, Never>?
    private var heightConstraint: NSLayoutConstraint?

    override func loadView() {
        inputView = KeyboardInputView(frame: .zero, inputViewStyle: .keyboard)
        inputView?.clipsToBounds = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        hasDictationKey = true
        model.keysChanged = { [weak self] in self?.refreshKeyboard() }
        configureEditing()
        model.resizeKeyboard = { [weak self] in self?.refreshKeyboard() }
        model.activationURLProvider = { [weak self] in
            guard let self else { return nil }
            return KeyboardActivationLink.url(host: hostResolver.host(for: self))
        }
        model.dismissKeyboard = { [weak self] in self?.dismissKeyboard() }
        configureDeletion()
        let host = UIHostingController(rootView: KeyboardView(
            model: model,
            insert: { [weak self] text in self?.textDocumentProxy.insertText(text) },
            start: { [weak self] in
                guard let self else { return }
                model.beginDictation(in: textDocumentProxy.documentIdentifier, language: primaryLanguage)
            },
            nextKeyboard: { [weak self] in self?.advanceToNextInputMode() },
            dismiss: { [weak self] in self?.dismissKeyboard() },
            nativeInput: true
        ))
        embed(host)
    }

    private func embed(_ host: UIHostingController<KeyboardView>) {
        hostedView = host.view
        host.safeAreaRegions = []
        host.view.backgroundColor = .clear
        view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let height = view.heightAnchor.constraint(equalToConstant: 221)
        height.priority = .init(999)
        height.isActive = true
        heightConstraint = height
        host.didMove(toParent: self)
        view.addSubview(plane)
    }

    private func configureEditing() {
        model.undoAction = { [weak self] in self?.undoManager?.undo() }
        model.redoAction = { [weak self] in self?.undoManager?.redo() }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let tablet = traitCollection.userInterfaceIdiom == .pad && view.bounds.width >= 600
        let landscape = tablet && (view.window?.windowScene?.interfaceOrientation.isLandscape ?? false)
        if model.tabletLayout != tablet {
            model.tabletLayout = tablet
        }
        if model.landscapeLayout != landscape {
            model.landscapeLayout = landscape
        }
        let compact = !model.tabletLayout && traitCollection.verticalSizeClass == .compact
        if model.compactLayout != compact {
            model.compactLayout = compact
        }
        updateHeight()
        updatePlane()
        let frame = view.convert(view.bounds, to: nil)
        if model.keyboardFrame != frame {
            model.keyboardFrame = frame
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        primaryLanguage = "pl-PL"
        hostResolver.appeared()
        model.connect(hasFullAccess: hasFullAccess, needsInputModeSwitchKey: needsInputModeSwitchKey)
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.poll()
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pollingTask?.cancel()
        pollingTask = nil
        model.cancelAutomaticInsertion()
        model.stopDeleting()
        model.accentPopup = nil
    }

    private func poll() {
        let undo = undoManager?.canUndo == true
        let redo = undoManager?.canRedo == true
        if model.canUndo != undo {
            model.canUndo = undo
        }
        if model.canRedo != redo {
            model.canRedo = redo
        }
        let activation = KeyboardActivationLink.url(host: hostResolver.host(for: self))
        if model.activationURL != activation {
            model.activationURL = activation
        }
        model.refresh()
        updateHeight()
        updatePlane()
        model.insertReadyResult(in: textDocumentProxy.documentIdentifier) { [weak self] text in
            self?.textDocumentProxy.insertText(text)
        }
    }

    private func refreshKeyboard() {
        updateHeight()
        updatePlane()
    }

    private func updatePlane() {
        let layout = KeyboardKeyLayout(
            width: view.bounds.width,
            tablet: model.tabletLayout,
            landscape: model.landscapeLayout || model.compactLayout,
            numbers: model.numbers,
            symbols: model.symbols,
            needsSwitch: model.needsInputModeSwitchKey
        )
        let top = model.noticeHeight(for: view.bounds.width) + (model.accentPopup?.topInset ?? 0)
            + (model.emojiSearchActive ? 147 : 0)
        let origin = layout.verticalOrigin(containerHeight: view.bounds.height, topInset: top)
        plane.frame = CGRect(x: 0, y: origin, width: layout.width, height: layout.height)
        plane.isHidden = model.emoji && !model.emojiSearchActive
        let keyboard = KeyboardKeyPlane(
            layout: layout,
            model: model,
            palette: KeyboardPalette(dark: traitCollection.userInterfaceStyle == .dark),
            insert: { [weak self] in self?.textDocumentProxy.insertText($0) },
            start: { [weak self] in self?.beginRecording() },
            nextKeyboard: { [weak self] in self?.advanceToNextInputMode() },
            dismiss: { [weak self] in self?.dismissKeyboard() },
            openApp: { [weak self] in self?.openContainingApp() }
        )
        keyboard.render(plane)
        if model.accentPopup != nil, let hostedView {
            view.bringSubviewToFront(hostedView)
        } else {
            view.bringSubviewToFront(plane)
        }
    }

    private func beginRecording() {
        model.beginDictation(in: textDocumentProxy.documentIdentifier, language: primaryLanguage)
    }

    private func openContainingApp() {
        guard let url = model.activationURLProvider() ?? model.activationURL else { return }
        guard let extensionContext else { model.openURL?(url); return }
        extensionContext.open(url) { [weak self] succeeded in
            guard !succeeded else { return }
            Task { @MainActor [weak self] in self?.model.openURL?(url) }
        }
    }

    private func updateHeight() {
        let metrics = KeyboardMetrics(
            width: view.bounds.width,
            tablet: model.tabletLayout,
            landscape: model.landscapeLayout,
            compact: model.compactLayout,
            noticeHeight: model.noticeHeight(for: view.bounds.width),
            emojiSearchActive: model.emoji && model.emojiSearchActive,
            accentTopInset: model.accentPopup?.topInset ?? 0,
            emojiVisible: model.emoji
        )
        if heightConstraint?.constant != metrics.height {
            heightConstraint?.constant = metrics.height
        }
    }
}

extension KeyboardViewController {
    private func configureDeletion() {
        model.configureDeletion { [weak self] unit in self?.delete(unit: unit) }
    }

    private func delete(unit: KeyboardDeletionUnit) {
        UIDevice.current.playInputClick()
        if model.emojiSearchActive {
            deleteFromSearch(unit: unit)
        } else {
            deleteFromDocument(unit: unit)
        }
    }

    private func deleteFromSearch(unit: KeyboardDeletionUnit) {
        guard !model.emojiQuery.isEmpty else { return }
        let count = unit == .word ? KeyboardWordDeletion.count(in: model.emojiQuery) : 1
        model.emojiQuery.removeLast(min(count, model.emojiQuery.count))
    }

    private func deleteFromDocument(unit: KeyboardDeletionUnit) {
        guard unit == .word else { textDocumentProxy.deleteBackward(); return }
        let count = KeyboardWordDeletion.count(
            in: textDocumentProxy.documentContextBeforeInput,
            hasSelection: textDocumentProxy.selectedText?.isEmpty == false
        )
        for _ in 0 ..< count {
            textDocumentProxy.deleteBackward()
        }
    }
}
