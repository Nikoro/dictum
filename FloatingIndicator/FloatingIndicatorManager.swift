import SwiftUI
import AppKit

// MARK: - Floating Indicator View

struct FloatingIndicatorView: View {
    let audioRecorder: AudioRecorder
    @ObservedObject var settings: AppSettings

    @State private var levels: [Float] = Array(repeating: 0, count: 16)
    @State private var smoothedLevel: Float = 0
    @State private var dotCount: Int = 0
    @State private var dotTimer: Timer?

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { context in
            HStack(spacing: 6) {
                switch settings.appState {
                case .recording:
                    recordingContent(time: context.date.timeIntervalSince1970)
                case .transcribing, .processingLLM:
                    transcribingContent
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .onChange(of: context.date) { _, _ in
                if settings.appState == .recording {
                    sampleLevel()
                }
            }
        }
    }

    private func recordingContent(time: Double) -> some View {
        HStack(spacing: 2.5) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white)
                    .frame(width: 3, height: barHeight(for: level, index: index, time: time))
            }
        }
        .frame(height: 24)
    }

    private var transcribingContent: some View {
        let base = String(localized: "pill.transcribing", defaultValue: "Transcribing")
        let dots = String(repeating: ".", count: dotCount + 1)
        let pad = String(repeating: " ", count: 3 - (dotCount + 1))
        return Text(base + dots + pad)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .fixedSize()
            .onAppear { startDotAnimation() }
            .onDisappear { stopDotAnimation() }
    }

    private func startDotAnimation() {
        guard dotTimer == nil else { return }
        dotCount = 0
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            DispatchQueue.main.async {
                dotCount = (dotCount + 1) % 3
            }
        }
    }

    private func stopDotAnimation() {
        dotTimer?.invalidate()
        dotTimer = nil
    }

    private func sampleLevel() {
        let raw = audioRecorder.audioLevel
        let db = 20 * log10(max(raw, 0.0001))
        let normalized = max(0, (db + 50) / 50)
        let boosted = pow(normalized, 0.7)
        smoothedLevel = smoothedLevel * 0.5 + Float(boosted) * 0.5
        levels.removeFirst()
        levels.append(smoothedLevel)
    }

    private func barHeight(for level: Float, index: Int, time: Double) -> CGFloat {
        let minH: CGFloat = 3
        let maxH: CGFloat = 20
        let phase = Double(index) * 0.4
        let wave = sin(time * 6 + phase) * 0.15 + 0.85
        let center = abs(Double(index) - 7.5) / 7.5
        let centerBoost = 1.0 - center * 0.3
        let h = minH + CGFloat(level) * CGFloat(wave * centerBoost) * (maxH - minH)
        return max(minH, h)
    }
}

// MARK: - Manager

@MainActor
final class FloatingIndicatorManager {
    static let shared = FloatingIndicatorManager()
    private var panel: NSPanel?
    private var hostingView: NSHostingView<FloatingIndicatorView>?
    private init() {}

    func show(audioRecorder: AudioRecorder) {
        guard panel == nil else { return }

        let view = FloatingIndicatorView(audioRecorder: audioRecorder, settings: AppSettings.shared)
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = [.intrinsicContentSize]

        let panelSize = NSSize(width: 180, height: 44)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        hosting.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = hosting

        let mouse = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(
            x: mouse.x - panelSize.width / 2,
            y: mouse.y - panelSize.height - 16
        ))

        panel.orderFrontRegardless()
        self.panel = panel
        self.hostingView = hosting
    }

    func hide() {
        guard let panel else { return }
        panel.orderOut(nil)
        self.panel = nil
        self.hostingView = nil
    }
}
