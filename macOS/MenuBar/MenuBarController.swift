import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    static var shared: MenuBarController?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    private let settings = AppSettings.shared
    private let runtimeState = AppRuntimeState.shared

    init() {
        MenuBarController.shared = self
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        observeState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = MenuBarIcon.microphone()
            button.setAccessibilityLabel("Dictum")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 560)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .tint(Color("AccentColor"))
                .environment(settings)
                .environment(runtimeState)
                .environment(WhisperModelStore.shared)
                .environment(DownloadedLLMModelStore.shared)
                .environment(LLMModelDownloadController.shared)
                .environment(SparkleUpdateController.shared)
                .environment(SystemPermissionStore.shared)
                .environment(HuggingFaceModelSearch.shared)
                .environment(WordReplacementStore.shared)
                .environment(ParakeetModelStore.shared)
        )
        self.popover = popover
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover?.performClose(nil)
        }
    }

    private func observeState() {
        let runtimeState = runtimeState
        Task { [weak self] in
            for await state in Observations({ runtimeState.appState }) {
                self?.updateIcon(for: state)
            }
        }
    }

    private func updateIcon(for state: AppState) {
        guard let button = statusItem?.button else { return }

        switch state {
        case .recording:
            button.image = MenuBarIcon.recording()
            button.setAccessibilityLabel(String(localized: "a11y.menuBar.recording", defaultValue: "Dictum, recording"))
        default:
            button.image = MenuBarIcon.microphone()
            button.setAccessibilityLabel("Dictum")
        }
    }

    func showPopover() {
        guard let popover, let button = statusItem?.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // Edge case: isolated, because the event monitor is not Sendable.
    isolated deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}
