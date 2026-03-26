import AppKit
import Carbon.HIToolbox
import Combine

@MainActor
final class GlobalHotkeyManager: ObservableObject {
    static let shared = GlobalHotkeyManager()

    @Published var isListening = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyDownHandler: (() -> Void)?
    private var keyUpHandler: (() -> Void)?

    private let settings = AppSettings.shared

    private init() {}

    var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func start(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.keyDownHandler = onKeyDown
        self.keyUpHandler = onKeyUp

        guard accessibilityGranted else {
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
    }

    private func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        // Store self reference for callback
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(type: type, event: event)
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
    }

    private nonisolated func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Check if this matches our hotkey
        let expectedKeyCode = Int64(AppSettings.shared.hotkeyKeyCode)
        let expectedModifiers = CGEventFlags(rawValue: UInt64(AppSettings.shared.hotkeyModifiers))

        // Check modifiers match (mask out non-modifier bits)
        let modifierMask: CGEventFlags = [.maskAlternate, .maskCommand, .maskControl, .maskShift]
        let currentModifiers = flags.intersection(modifierMask)
        let expectedMods = expectedModifiers.intersection(modifierMask)

        guard keyCode == expectedKeyCode && currentModifiers == expectedMods else {
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown {
            DispatchQueue.main.async { [weak self] in
                self?.keyDownHandler?()
            }
            return nil // Consume the event
        } else if type == .keyUp {
            DispatchQueue.main.async { [weak self] in
                self?.keyUpHandler?()
            }
            return nil
        }

        return Unmanaged.passRetained(event)
    }
}
