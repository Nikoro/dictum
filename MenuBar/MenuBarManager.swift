import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarManager: ObservableObject {
    static weak var shared: MenuBarManager?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    private let settings = AppSettings.shared
    private let pipeline = DictationPipeline.shared

    init() {
        MenuBarManager.shared = self
        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        observeState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = MenuBarIcon.microphone(state: .idle)
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 640)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .tint(Color("AccentColor"))
                .environmentObject(settings)
                .environmentObject(pipeline)
        )
        self.popover = popover
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover?.performClose(nil)
        }
    }

    private func observeState() {
        settings.$appState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateIcon(for: state)
            }
            .store(in: &cancellables)
    }

    private func updateIcon(for state: AppState) {
        guard let button = statusItem?.button else { return }

        switch state {
        case .recording:
            // Kolorowa ikona z czerwoną kropką REC
            button.image = MenuBarIcon.recording()
        case .done:
            button.image = MenuBarIcon.microphone(state: .done)
            // Flash back to idle after 1s
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.settings.appState = .idle
            }
        default:
            // Template image — system automatycznie dopasuje do light/dark mode
            button.image = MenuBarIcon.microphone(state: state)
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

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}
