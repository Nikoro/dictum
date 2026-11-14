import Foundation
import Observation

@Observable
@MainActor
final class KeyboardModel {
    private(set) var session: KeyboardSession?
    private(set) var hasFullAccess = false
    private(set) var needsInputModeSwitchKey = true
    private(set) var pending = false
    private(set) var bridgeFailed = false
    private var noticeState = KeyboardNoticeState()
    var shift = KeyboardShiftState()
    var uppercase: Bool {
        shift.isUppercase
    }

    @ObservationIgnored var moveCursor: (Int) -> Void = { _ in }
    var numbers = false
    var symbols = false
    var emoji = false
    var emojiSearchActive = false
    var emojiQuery = ""
    let emojiPreferences = EmojiPreferences()
    var compactLayout = false
    var tabletLayout = false
    var landscapeLayout = false
    var canUndo = false
    var canRedo = false
    @ObservationIgnored var undoAction: () -> Void = {}
    @ObservationIgnored var redoAction: () -> Void = {}
    var activationURL = URL(string: "dictum://session")
    @ObservationIgnored var activationURLProvider: () -> URL? = { nil }
    var keyboardFrame = CGRect.zero
    var accentPopup: KeyboardAccentSelection?
    @ObservationIgnored var openURL: ((URL) -> Void)?
    @ObservationIgnored var keysChanged: () -> Void = {}
    @ObservationIgnored var dismissKeyboard: () -> Void = {}
    @ObservationIgnored var resizeKeyboard: () -> Void = {}

    @ObservationIgnored private var mailbox: KeyboardMailbox?
    @ObservationIgnored private var pendingSince: Date?
    @ObservationIgnored private var pendingPhase: KeyboardSession.Phase?
    @ObservationIgnored private var delivery = KeyboardResultDelivery()
    @ObservationIgnored private var deletion: RepeatingKeyAction?

    var notice: String? {
        noticeState.visibleMessage
    }

    func noticeHeight(for width: CGFloat) -> CGFloat {
        KeyboardNoticeLayout.height(message: notice, width: width)
    }

    func dismissNotice() {
        guard notice != nil else { return }
        noticeState.dismiss()
        resizeKeyboard()
    }

    private func updateNotice() {
        let message = currentNotice
        guard message != noticeState.message else { return }
        let previous = notice
        noticeState.update(message)
        if previous != notice {
            resizeKeyboard()
        }
    }

    private var currentNotice: String? {
        if !hasFullAccess {
            return String(localized: "ios.keyboard.full_access")
        }
        if bridgeFailed {
            return String(localized: "ios.error.bridge")
        }
        return session?.issue?.message
    }

    func showAccents(_ popup: KeyboardAccentSelection) {
        accentPopup = popup
        resizeKeyboard()
    }

    func hideAccents(owner: UUID) {
        guard accentPopup?.owner == owner else { return }
        accentPopup = nil
        resizeKeyboard()
    }

    func configureDeletion(_ action: @escaping (KeyboardDeletionUnit) -> Void) {
        deletion?.release()
        deletion = RepeatingKeyAction(acceleratedAction: { action(.word) }, action: { action(.character) })
    }

    func startDeleting() {
        deletion?.press()
    }

    func stopDeleting() {
        deletion?.release()
    }

    func connect(hasFullAccess: Bool, needsInputModeSwitchKey: Bool) {
        self.hasFullAccess = hasFullAccess
        self.needsInputModeSwitchKey = needsInputModeSwitchKey
        guard hasFullAccess,
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: KeyboardMailbox.appGroup)
        else {
            mailbox = nil
            session = nil
            updateNotice()
            return
        }
        mailbox = try? KeyboardMailbox(directory: root.appendingPathComponent("KeyboardSession", isDirectory: true))
        bridgeFailed = mailbox == nil
        refresh()
    }

    func refresh() {
        defer { updateNotice() }
        do {
            let latest = try mailbox?.readSession()
            bridgeFailed = mailbox == nil
            session = latest?.isAvailable(at: Date()) == true ? latest : nil
            delivery.observe(session)
            if let pendingSince,
               session?.phase != pendingPhase || Date().timeIntervalSince(pendingSince) > 4
            {
                pending = false
                self.pendingSince = nil
            }
        } catch {
            session = nil
            bridgeFailed = true
        }
    }

    func send(_ action: KeyboardCommand.Action, language: String? = nil) {
        defer { updateNotice() }
        if action == .cancel {
            delivery.cancel()
        }
        guard let session, !pending else { return }
        do {
            guard let mailbox else { return }
            try mailbox.send(KeyboardCommand(
                sessionID: session.id,
                recordingID: session.recordingID,
                action: action,
                language: language
            ))
            pending = true
            pendingSince = Date()
            pendingPhase = session.phase
        } catch {
            bridgeFailed = true
        }
    }

    func beginDictation(in documentID: UUID, language: String? = nil) {
        guard let session, session.phase == .ready, !pending else { return }
        dismissNotice()
        delivery.begin(sessionID: session.id, documentID: documentID)
        send(.start, language: language)
    }

    func insertReadyResult(in documentID: UUID, using insert: (String) -> Void) {
        guard let session, !pending else { return }
        switch delivery.result(from: session, in: documentID, at: Date()) {
        case .waiting: return
        case let .insert(text): insert(text)
        case .discard: break
        }
        send(.consume)
    }

    func cancelAutomaticInsertion() {
        delivery.cancel()
    }

    #if DEBUG
    static func recordingPreview() -> KeyboardModel {
        let model = KeyboardModel()
        model.session = KeyboardSession(id: UUID(), updatedAt: .now, phase: .recording)
        model.hasFullAccess = true
        model.needsInputModeSwitchKey = false
        return model
    }
    #endif
}
