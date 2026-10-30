---
name: dictum-qa
description: Manual QA checklist for the running Dictum app, covering what the DictumTests unit tests cannot (UI, audio, permissions, models). Lists which scenarios to run for which change (dictation, hotkey modes, cancel, Bluetooth input, context mode, LLM cleanup, setup wizard, model management, prompts, permissions, microphone choice, long dictation, engines, dictionary) and what to look for in the app and in ~/Library/Logs/Dictum/dictum.log. Use after a change, before committing or releasing, or when the user asks to test or QA Dictum.
---

# dictum-qa

Run against a fresh build: `spells run`. Keep `tail -f ~/Library/Logs/Dictum/dictum.log` open.
An agent that cannot press keys or speak runs the log and launch checks plus the Debug
transcription harness (`docs/development.md`) on synthetic speech, then hands the interactive
sections to the user as a short list, naming only the sections the change touches.

## Pick the sections

| Change touches | Sections |
| --- | --- |
| `Audio/`, `DictationPipeline`, `DictationProcessor` | 1, 2, 3, 4, 12, 13 |
| `HotkeyAndPaste/` | 1, 2, 3, 5 |
| `Context/`, `TextProcessing/`, prompts | 5, 6, 9 |
| `Transcription/`, `ModelBrowser/`, model views | 1, 7, 8, 13, 14 |
| `MenuBar/` setup or permission views | 7, 10 |
| Settings or any view | the affected screen, plus 11 |
| Release candidate | all |

## 0. Launch

- `spells run` prints `Dictum is running`.
- Log shows `[Hotkey] event tap created and enabled`, then STT preload and `warmup complete`.

## 1. Basic dictation (hold mode)

- Focus a text field, hold Right Command, speak a Polish sentence, release.
- The pill appears next to the caret with the app icon and live level bars, then
  "Transcribing…", and the text is pasted. The previous clipboard content is restored.
- Log: `samples=` is non-zero, transcription length, `pasting`.

## 2. Toggle mode

- Switch mode to toggle; press once to start, once to stop. Same result as 1.

## 3. Cancel

- Start recording, press Escape. The pill disappears, nothing is pasted, the log shows
  `cancel requested`, and no transcription or LLM work continues afterwards.

## 4. Bluetooth input

- Set a Bluetooth headset as the input, dictate. Log shows `configuration changed` /
  `engine restarted` and `samples=` is non-zero. An empty recording here is the A2DP→HFP bug.

## 5. Context mode

- Select text in an app, dictate. The result is copied to the clipboard, not pasted over the
  selection. Log: `context mode`.

## 6. LLM cleanup

- With cleanup on and a model downloaded, dictate with filler words; output is cleaned.
- Delete or unload the model mid-session: dictation falls back to the raw text
  (`LLM cleanup failed, using raw text`), never fails silently.

## 7. Setup wizard

- On a fresh profile (`defaults delete com.dominikkrajcer.dictum` on a test account): grant
  permissions, download an STT model (cancel once mid-download, then restart it), pick an LLM or
  skip. Each step unlocks the next; the checkmarks match the state.

## 8. Model management

- Switch the active STT model, including to and from Parakeet in the same list; dictation uses
  it right away (log shows the model id on load, no restart needed).
- Downloaded models lists each model once, every STT model (Parakeet too) and only Dictum's
  LLMs, never other tools' models from `~/.cache/huggingface`.
- Delete a non-active model: confirmation alert with the size, disk usage summary updates.
- The active STT model's trash button is disabled with a tooltip.
- HuggingFace search: 1 character shows the hint, 2+ show results, downloading shows progress
  and can be cancelled.

## 9. Prompts

- Edit the system prompt, reopen the popover: the edit is kept. Reset restores the default.
- Add a per-app prompt, dictate in that app: the log shows `LLM prompt for <bundle id>`.

## 10. Permissions

- Revoke Microphone or Accessibility in System Settings: the popover shows "Permissions
  needed" with only the missing ones, and "Enable" opens the right pane.

## 11. Localization

- With the system in Polish, every label in the touched screens is Polish (an English label
  means a missing key; `check_strings.py` should have caught it).

## 12. Microphone choice

- Pick a non-default input in Microphone; dictation records from it (log: `input device
  selected, status 0`). Unplug it: the next recording falls back to the system default.

## 13. Long dictation and silence

- Speak for over 30 s with pauses: the log shows `[STT] chunk:` lines during recording, and the
  text after key-up has no words cut at chunk borders.
- Hold the hotkey without speaking: nothing is pasted (`no speech, going idle`).

## 14. Engines, dictionary, idle unload

- Download Parakeet TDT v3 from the STT list (progress bar, cancel works), dictate: noticeably
  faster result. Switch back to Whisper, then delete Parakeet from Downloaded models.
- Add a dictionary rule, dictate the heard word: the replacement is pasted.
- With "Free memory after" set to 5 min, wait: the log shows `unloading models`; the next
  dictation still works (models reload while you speak).
