# Architecture

- `DictumApp` calls `DictationPipeline.shared.start()` at launch; nothing else creates the
  pipeline, so without that call the hotkey is never registered.
- A new `@Observable` store read by views must be injected in `MenuBarController.setupPopover`,
  or the popover crashes when opened.
- The CGEvent tap callback must stay fast: macOS disables a slow tap and the hotkey dies. No I/O,
  per-event logging or waiting on that path.
- No transcription history is stored, by design.
- Uninstall deletes the shared MLX cache root, not only Dictum-owned models.
