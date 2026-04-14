# UI & Rendering

### [GOTCHA] [GOTCHA] `.background(.ultraThinMaterial)` kills `.glassEffect()` rendering
**Area:** `FloatingIndicator/FloatingIndicatorView.swift`
**Tags:** `#gotcha` `#integration`
**Verified:** 2026-03-26
**Symptom:** Floating pill renders with flat black background instead of liquid glass effect.
**Root cause:** `.background(.ultraThinMaterial, in: Capsule())` applied before `.glassEffect(.regular, in: .capsule)` overrides the glass rendering. The material fills the shape opaquely.
**Workaround:** Remove `.background(.ultraThinMaterial)` entirely. Use `.glassEffect()` alone — it provides its own translucency.

### [GOTCHA] [NOTE] TimelineView reconstructs child views — onAppear fires repeatedly
**Area:** `FloatingIndicator/FloatingIndicatorView.swift`
**Tags:** `#gotcha` `#architecture`
**Verified:** 2026-03-26
**Symptom:** Dot animation timer multiplied — "Transkrybuję" showed 4-6 dots instead of max 3.
**Root cause:** Views inside `TimelineView(.animation)` get reconstructed every frame (~60Hz). Each reconstruction can trigger `.onAppear`, creating duplicate `Timer.scheduledTimer` instances.
**Workaround:** Guard timer creation with `guard dotTimer == nil`, store timer in `@State`, and clean up on `.onDisappear`.

### [GOTCHA] [NOTE] @Published changes don't propagate across NSPanel window boundary
**Area:** `FloatingIndicator/FloatingIndicatorView.swift`
**Tags:** `#gotcha` `#architecture`
**Verified:** 2026-03-26
**Symptom:** Audio level bars in floating pill don't move despite `audioLevel` being updated in `AudioRecorder`.
**Root cause:** `@Published` property changes from `ObservableObject` in the main app don't reliably trigger `@ObservedObject` updates in a SwiftUI view hosted in a separate `NSPanel` window.
**Workaround:** Use `TimelineView(.animation(minimumInterval: 0.016))` to poll `audioRecorder.audioLevel` directly at 60Hz instead of relying on Combine observation.
