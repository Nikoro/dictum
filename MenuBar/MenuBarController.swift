import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarController: ObservableObject {
    static var shared: MenuBarController?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    private let settings = AppSettings.shared
    private let runtimeState = AppRuntimeState.shared
    private let pipeline = DictationPipeline.shared

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
                .environmentObject(settings)
                .environmentObject(runtimeState)
                .environmentObject(pipeline)
                .environmentObject(SparkleUpdateController.shared)
                .environmentObject(SystemPermissionStore.shared)
                .environmentObject(HuggingFaceModelSearch.shared)
        )
        self.popover = popover
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover?.performClose(nil)
        }
    }

    private func observeState() {
        runtimeState.$appState
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
            button.image = MenuBarIcon.recording()
        default:
            // Template image — system automatycznie dopasuje do light/dark mode
            button.image = MenuBarIcon.microphone()
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
