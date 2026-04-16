import AppKit
import Carbon.HIToolbox
import Combine
import os

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

    /// Thread-safe cached hotkey config, read from the CGEvent tap thread
    private struct CachedHotkeyConfig: Sendable {
        var isModifierOnly: Bool = true
        var keyCode: Int = 54
        var modifiers: Int = 0
        var isActive: Bool = false
    }

    private let cachedConfig = OSAllocatedUnfairLock(initialState: CachedHotkeyConfig())

    /// Tracks whether a modifier-only hotkey is currently "pressed"
    private var modifierKeyDown = false

    nonisolated var isActive: Bool {
        get { cachedConfig.withLock { $0.isActive } }
        set { cachedConfig.withLock { $0.isActive = newValue } }
    }

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
        let isModOnly = settings.hotkeyIsModifierOnly
        let keyCode = settings.hotkeyKeyCode
        let mods = settings.hotkeyModifiers
        cachedConfig.withLock { config in
            config.isModifierOnly = isModOnly
            config.keyCode = keyCode
            config.modifiers = mods
        }

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
            dlog("[Hotkey] failed to create event tap — accessibility permission required")
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
        let snapshot = cachedConfig.withLock { $0 }
        let isModifierOnly = snapshot.isModifierOnly
        let expectedKeyCode = Int64(snapshot.keyCode)

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
                expectedModifiers: snapshot.modifiers,
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
        guard type == .keyDown, keyCode == Int64(KeyCode.escape), isActive else {
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
                    DictationPipeline.shared.setPendingContext(selectedText)
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
        expectedModifiers modifiersRaw: Int,
        flags: CGEventFlags,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        let expectedModifiers = CGEventFlags(rawValue: UInt64(modifiersRaw))
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
                    DictationPipeline.shared.setPendingContext(selectedText)
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
