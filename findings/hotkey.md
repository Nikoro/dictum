# Paste & Hotkey

### [BUG] [GOTCHA] CGEvent paste requires `.cgAnnotatedSessionEventTap`
**Area:** `HotkeyAndPaste/ClipboardPasteController.swift`
**Tags:** `#gotcha` `#integration`
**Verified:** 2026-03-26
**Trigger:** Transcription completes, clipboard is set, Cmd+V is simulated, but nothing pastes into the target app.
**Root cause:** Events posted to `.cghidEventTap` weren't reaching the frontmost app reliably. The app's own CGEvent tap for hotkey detection may also interfere.
**Fix applied:** Changed all 4 CGEvent posts (Cmd↓, V↓, V↑, Cmd↑) to use `.cgAnnotatedSessionEventTap`. Also increased pre-paste delay to 0.15s and clipboard restore delay to 0.5s.

### [GOTCHA] [NOTE] SelectedTextCapture.readSelectedText() must never run on event tap's run loop thread
**Area:** `HotkeyAndPaste/SelectedTextCapture.swift`, `HotkeyAndPaste/GlobalHotkeyMonitor.swift`
**Tags:** `#gotcha` `#architecture`
**Verified:** 2026-03-28
**Symptom:** `readSelectedText()` returns `nil` (clipboard unchanged) even when text is selected.
**Root cause:** The method sends Cmd+C via `.cghidEventTap` then `Thread.sleep(0.05)` to wait for clipboard. If called on the same run loop thread that processes CGEvents, the sleep blocks delivery of the very event it just posted → deadlock (clipboard never updates).
**Workaround:** `GlobalHotkeyMonitor` correctly dispatches to `DispatchQueue.global` before calling. If the call site ever moves, the bug is silent (no crash, just `nil` return).
**Note on timing:** The 50ms `Thread.sleep` is a hardcoded timing assumption. If the clipboard doesn't update within 50ms (e.g., slow/Electron apps), context mode silently degrades to plain transcription (no selected text context) without any user feedback.

### [GOTCHA] [NOTE] GlobalHotkeyMonitor uses nonisolated(unsafe) cache — safe only under current usage
**Area:** `HotkeyAndPaste/GlobalHotkeyMonitor.swift`
**Tags:** `#gotcha` `#architecture`
**Verified:** 2026-04-04
**Symptom:** Three `nonisolated(unsafe)` vars (`cachedIsModifierOnly`, `cachedKeyCode`, `cachedModifiers`) are written on the main actor in `start()` and read from the CGEvent tap thread with no synchronization.
**Root cause:** Deliberate data race tradeoff — the cache is written once before `setupEventTap()` is called, and the tap is torn down and rebuilt on hotkey changes. Safe under current usage.
**Risk:** If `start()` is ever called while the tap is running (e.g., dynamic hotkey reconfiguration without teardown), the tap could read stale values. Adding a dynamic update path would need synchronization.
