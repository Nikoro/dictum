import Observation

@MainActor
final class DictationHotkeyController {
    static let shared = DictationHotkeyController()

    private let hotkeyMonitor = GlobalHotkeyMonitor.shared
    private let permissionStore = SystemPermissionStore.shared
    private let settings = AppSettings.shared
    private var pipeline: DictationPipeline {
        DictationPipeline.shared
    }

    private init() {}

    func start() {
        register()
        reregisterWhenAccessibilityIsGranted()
    }

    func register() {
        hotkeyMonitor.start(
            onKeyDown: { [weak self] in
                Task { @MainActor in await self?.keyDown() }
            },
            onKeyUp: { [weak self] in
                Task { @MainActor in await self?.keyUp() }
            },
            onCancel: { [weak self] in
                Task { @MainActor in self?.pipeline.cancelOperation() }
            }
        )
    }

    func unregister() {
        hotkeyMonitor.stop()
    }

    private func reregisterWhenAccessibilityIsGranted() {
        let permissionStore = permissionStore
        Task { [weak self] in
            var wasGranted = false
            for await isGranted in Observations({ permissionStore.accessibilityGranted }) {
                defer { wasGranted = isGranted }
                guard isGranted, !wasGranted, let self, !hotkeyMonitor.isListening else { continue }
                dlog("[Dictum] Accessibility granted, registering hotkey")
                register()
            }
        }
    }

    private func keyDown() async {
        dlog("[Dictum] key down, mode=\(settings.recordingMode), isRecording=\(pipeline.isRecording)")
        switch settings.recordingMode {
        case .hold where !pipeline.isRecording:
            pipeline.startRecording()
        case .toggle where pipeline.isRecording:
            await pipeline.stopRecordingAndProcess()
        case .toggle:
            pipeline.startRecording()
        case .hold:
            break
        }
    }

    private func keyUp() async {
        guard settings.recordingMode == .hold, pipeline.isRecording else { return }
        await pipeline.stopRecordingAndProcess()
    }
}
