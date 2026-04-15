import AppKit
import Carbon.HIToolbox
import Combine

@MainActor
final class GlobalHotkeyMonitor: ObservableObject {
    static let shared = GlobalHotkeyMonitor()

    @Published var isListening = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyDownHandler: (() -> Void)?
    private var keyUpHandler: (() -> Void)?
    private var cancelHandler: (() -> Void)?

    private let settings = AppSettings.shared

    /// Cached hotkey settings for safe access from nonisolated event tap callback
    private nonisolated(unsafe) var cachedIsModifierOnly: Bool = true
    private nonisolated(unsafe) var cachedKeyCode: Int = 54
    private nonisolated(unsafe) var cachedModifiers: Int = 0

    /// Tracks whether a modifier-only hotkey is currently "pressed"
    private var modifierKeyDown = false

    private init() {}

    var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func start(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void, onCancel: @escaping () -> Void) {
        // Tear down any existing event tap before creating a new one
        stop()

        self.keyDownHandler = onKeyDown
        self.keyUpHandler = onKeyUp
        self.cancelHandler = onCancel

        dlog(
            "[Hotkey] start() called, accessibility=\(accessibilityGranted), " +
            "keyCode=\(settings.hotkeyKeyCode), " +
            "isModifierOnly=\(settings.hotkeyIsModifierOnly)"
        )

        // Cache settings for safe access from nonisolated event tap callback
        cachedIsModifierOnly = settings.hotkeyIsModifierOnly
        cachedKeyCode = settings.hotkeyKeyCode
        cachedModifiers = settings.hotkeyModifiers

        guard accessibilityGranted else {
            dlog("[Hotkey] accessibility NOT granted, requesting...")
            requestAccessibility()
            return
        }

        setupEventTap()
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        isListening = false
        modifierKeyDown = false
    }

    private func setupEventTap() {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        // Store self reference for callback
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            print("Failed to create event tap. Accessibility permission required.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        isListening = true
        dlog("[Hotkey] event tap created and enabled")
    }

    private nonisolated func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let isModifierOnly = cachedIsModifierOnly
        let expectedKeyCode = Int64(cachedKeyCode)

        if handleEscapeKey(type: type, keyCode: keyCode, event: event) != nil {
            return Unmanaged.passRetained(event)
        }

        if isModifierOnly {
            return handleModifierOnlyEvent(
                type: type,
                keyCode: keyCode,
                expectedKeyCode: expectedKeyCode,
                flags: flags,
                event: event
            )
        } else {
            return handleKeyComboEvent(
                type: type,
                keyCode: keyCode,
                expectedKeyCode: expectedKeyCode,
                flags: flags,
                event: event
            )
        }
    }

    private nonisolated func handleEscapeKey(
        type: CGEventType,
        keyCode: Int64,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        guard type == .keyDown, keyCode == 53 else {
            return nil
        }

        DispatchQueue.main.async { [weak self] in
            self?.cancelHandler?()
        }
        return Unmanaged.passRetained(event)
    }

    private nonisolated func handleModifierOnlyEvent(
        type: CGEventType,
        keyCode: Int64,
        expectedKeyCode: Int64,
        flags: CGEventFlags,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .flagsChanged {
            dlog("[Hotkey] flagsChanged: keyCode=\(keyCode), expected=\(expectedKeyCode), flags=\(flags.rawValue)")
        }

        guard type == .flagsChanged, keyCode == expectedKeyCode else {
            return Unmanaged.passRetained(event)
        }

        let modifierFlag = Self.modifierFlag(forKeyCode: Int(expectedKeyCode))
        let isPressed = flags.contains(modifierFlag)
        dlog("[Hotkey] modifier match! isPressed=\(isPressed)")

        if isPressed {
            captureSelectedText { [weak self] selectedText in
                Task { @MainActor in
                    guard let self else { return }
                    DictationPipeline.shared.pendingSelectedContext = selectedText
                    self.modifierKeyDown = true
                    self.keyDownHandler?()
                }
            }
            return nil
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.modifierKeyDown else { return }
            self.modifierKeyDown = false
            self.keyUpHandler?()
        }
        return nil
    }

    private nonisolated func handleKeyComboEvent(
        type: CGEventType,
        keyCode: Int64,
        expectedKeyCode: Int64,
        flags: CGEventFlags,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        let expectedModifiers = CGEventFlags(rawValue: UInt64(cachedModifiers))
        let modifierMask: CGEventFlags = [.maskAlternate, .maskCommand, .maskControl, .maskShift]
        let currentModifiers = flags.intersection(modifierMask)
        let expectedMods = expectedModifiers.intersection(modifierMask)

        guard keyCode == expectedKeyCode, currentModifiers == expectedMods else {
            return Unmanaged.passRetained(event)
        }

        switch type {
        case .keyDown:
            captureSelectedText { [weak self] selectedText in
                Task { @MainActor in
                    DictationPipeline.shared.pendingSelectedContext = selectedText
                    self?.keyDownHandler?()
                }
            }
            return nil
        case .keyUp:
            DispatchQueue.main.async { [weak self] in
                self?.keyUpHandler?()
            }
            return nil
        default:
            return Unmanaged.passRetained(event)
        }
    }

    private nonisolated func captureSelectedText(
        completion: @escaping (String?) -> Void
    ) {
        DispatchQueue.global(qos: .userInteractive).async {
            let selectedText = SelectedTextCapture.readSelectedText()
            DispatchQueue.main.async {
                completion(selectedText)
            }
        }
    }

    // MARK: - Helpers

    /// Maps a modifier keyCode to the corresponding CGEventFlags bit.
    nonisolated static func modifierFlag(forKeyCode keyCode: Int) -> CGEventFlags {
        switch keyCode {
        case 54, 55: return .maskCommand     // Right/Left Command
        case 56, 60: return .maskShift       // Left/Right Shift
        case 58, 61: return .maskAlternate   // Left/Right Option
        case 59, 62: return .maskControl     // Left/Right Control
        default: return []
        }
    }

    /// Whether a keyCode is a modifier key.
    nonisolated static func isModifierKeyCode(_ keyCode: Int) -> Bool {
        [54, 55, 56, 57, 58, 59, 60, 61, 62].contains(keyCode)
    }

    /// Human-readable name for a modifier keyCode.
    nonisolated static func modifierKeyName(_ keyCode: Int) -> String? {
        let right = String(localized: "hotkey.right", defaultValue: "Right")
        let left = String(localized: "hotkey.left", defaultValue: "Left")
        switch keyCode {
        case 54: return "\(right) ⌘"
        case 55: return "\(left) ⌘"
        case 56: return "\(left) ⇧"
        case 60: return "\(right) ⇧"
        case 58: return "\(left) ⌥"
        case 61: return "\(right) ⌥"
        case 59: return "\(left) ⌃"
        case 62: return "\(right) ⌃"
        default: return nil
        }
    }
}
