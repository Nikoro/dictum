import AppKit
import Carbon.HIToolbox
import os

@MainActor
final class GlobalHotkeyMonitor {
    static let shared = GlobalHotkeyMonitor()

    var isListening = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyDownHandler: (() -> Void)?
    private var keyUpHandler: (() -> Void)?
    private var cancelHandler: (() -> Void)?

    private let settings = AppSettings.shared

    private struct HotkeyConfig: Sendable {
        var isModifierOnly: Bool = true
        var keyCode = Int(KeyCode.rightCommand)
        var modifiers: Int = 0
        var isActive: Bool = false
    }

    private let cachedConfig = OSAllocatedUnfairLock(initialState: HotkeyConfig())

    private var isModifierHotkeyHeld = false

    nonisolated var isActive: Bool {
        get { cachedConfig.withLock { $0.isActive } }
        set { cachedConfig.withLock { $0.isActive = newValue } }
    }

    private init() {}

    private var permissionStore: SystemPermissionStore {
        SystemPermissionStore.shared
    }

    func start(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void, onCancel: @escaping () -> Void) {
        stop()

        keyDownHandler = onKeyDown
        keyUpHandler = onKeyUp
        cancelHandler = onCancel

        dlog(
            "[Hotkey] start() called, accessibility=\(permissionStore.accessibilityGranted), " +
                "keyCode=\(settings.hotkeyKeyCode), " +
                "isModifierOnly=\(settings.hotkeyIsModifierOnly)"
        )

        let isModOnly = settings.hotkeyIsModifierOnly
        let keyCode = settings.hotkeyKeyCode
        let mods = settings.hotkeyModifiers
        cachedConfig.withLock { config in
            config.isModifierOnly = isModOnly
            config.keyCode = keyCode
            config.modifiers = mods
        }

        guard permissionStore.accessibilityGranted else {
            dlog("[Hotkey] accessibility NOT granted, requesting...")
            permissionStore.requestAccessibility()
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
            CFMachPortInvalidate(eventTap)
        }
        eventTap = nil
        runLoopSource = nil
        isListening = false
        isModifierHotkeyHeld = false
    }

    private func reenableTap(disabledBy type: CGEventType) {
        guard let eventTap else { return }
        let reason = type == .tapDisabledByTimeout ? "timeout" : "user input"
        dlog("[Hotkey] tap disabled by \(reason), re-enabling")
        // Edge case: a key-up missed while disabled would leave the press half-finished.
        isModifierHotkeyHeld = false
        isActive = false
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func setupEventTap() {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

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
        )
        else {
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
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Task { @MainActor [weak self] in
                self?.reenableTap(disabledBy: type)
            }
            return nil
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if cancelsDictationOnEscape(type: type, keyCode: keyCode) {
            return Unmanaged.passRetained(event)
        }

        let config = cachedConfig.withLock { $0 }
        let isHotkey = config.isModifierOnly
            ? consumeModifierOnlyHotkey(type: type, keyCode: keyCode, flags: event.flags, config: config)
            : consumeKeyComboHotkey(type: type, keyCode: keyCode, flags: event.flags, config: config)
        return isHotkey ? nil : Unmanaged.passRetained(event)
    }

    private nonisolated func cancelsDictationOnEscape(type: CGEventType, keyCode: Int64) -> Bool {
        guard type == .keyDown, keyCode == Int64(KeyCode.escape), isActive else {
            return false
        }

        DispatchQueue.main.async { [weak self] in
            self?.cancelHandler?()
        }
        return true
    }

    private nonisolated func consumeModifierOnlyHotkey(
        type: CGEventType,
        keyCode: Int64,
        flags: CGEventFlags,
        config: HotkeyConfig
    ) -> Bool {
        // Edge case: never log here, this runs for every modifier press system-wide.
        guard type == .flagsChanged, keyCode == Int64(config.keyCode) else {
            return false
        }

        if flags.contains(ModifierKey.flag(forKeyCode: config.keyCode)) {
            beginPress(tracksModifier: true)
        } else {
            Task { @MainActor [weak self] in
                guard let self, isModifierHotkeyHeld else { return }
                isModifierHotkeyHeld = false
                keyUpHandler?()
            }
        }
        return true
    }

    private nonisolated func consumeKeyComboHotkey(
        type: CGEventType,
        keyCode: Int64,
        flags: CGEventFlags,
        config: HotkeyConfig
    ) -> Bool {
        let modifierMask: CGEventFlags = [.maskAlternate, .maskCommand, .maskControl, .maskShift]
        let expectedModifiers = CGEventFlags(rawValue: UInt64(config.modifiers)).intersection(modifierMask)
        guard keyCode == Int64(config.keyCode), flags.intersection(modifierMask) == expectedModifiers else {
            return false
        }

        switch type {
        case .keyDown:
            beginPress(tracksModifier: false)
            return true
        case .keyUp:
            Task { @MainActor [weak self] in
                self?.keyUpHandler?()
            }
            return true
        default:
            return false
        }
    }

    private nonisolated func beginPress(tracksModifier: Bool) {
        Task.detached(priority: .userInitiated) { [weak self] in
            let selectedText = SelectedTextCapture.readSelectedText()
            await MainActor.run { [weak self] in
                guard let self else { return }
                DictationPipeline.shared.setPendingContext(selectedText)
                if tracksModifier {
                    isModifierHotkeyHeld = true
                }
                keyDownHandler?()
            }
        }
    }
}
