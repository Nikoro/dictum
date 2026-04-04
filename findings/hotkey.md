# Paste & Hotkey

### [BUG] [GOTCHA] CGEvent paste requires `.cgAnnotatedSessionEventTap`
**Area:** `HotkeyAndPaste/PasteManager.swift`
**Tags:** `#gotcha` `#integration`
**Verified:** 2026-03-26
**Trigger:** Transcription completes, clipboard is set, Cmd+V is simulated, but nothing pastes into the target app.
**Root cause:** Events posted to `.cghidEventTap` weren't reaching the frontmost app reliably. The app's own CGEvent tap for hotkey detection may also interfere.
**Fix applied:** Changed all 4 CGEvent posts (Cmd↓, V↓, V↑, Cmd↑) to use `.cgAnnotatedSessionEventTap`. Also increased pre-paste delay to 0.15s and clipboard restore delay to 0.5s.

### [GOTCHA] [NOTE] SelectedTextReader.readSelectedText() must never run on event tap's run loop thread
**Area:** `HotkeyAndPaste/SelectedTextReader.swift`, `HotkeyAndPaste/GlobalHotkeyManager.swift`
**Tags:** `#gotcha` `#architecture`
**Verified:** 2026-03-28
**Symptom:** `readSelectedText()` returns `nil` (clipboard unchanged) even when text is selected.
**Root cause:** The method sends Cmd+C via `.cghidEventTap` then `Thread.sleep(0.05)` to wait for clipboard. If called on the same run loop thread that processes CGEvents, the sleep blocks delivery of the very event it just posted → deadlock (clipboard never updates).
**Workaround:** `GlobalHotkeyManager` correctly dispatches to `DispatchQueue.global` before calling. If the call site ever moves, the bug is silent (no crash, just `nil` return).
