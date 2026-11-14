# Dictum roadmap

Updated: 2026-11-14. These are planned tasks and research notes, not implemented features or release commitments.
The next major exploration is local reply suggestions on iPhone and iPad, alongside practical improvements
to dictation recovery and reusable phrases. Implementation order below is proposed, not a fixed schedule.

## Local reply suggestions on iPhone and iPad

Status: planned; device feasibility work required. Initial target: the owner's iPhone 17.

### Intended experience

Show a compact strip above the keyboard with ready-to-use replies. Tapping a suggestion inserts it into
the current editor without requiring dictation and without sending the message. Suggestions should match
the language of the supplied conversation. The longer-term goal is context-aware assistance similar to
Dictum's macOS context mode.

Three layers:

1. Instant responses such as thumbs-up, OK, understood and thanks, available without loading an LLM.
2. Three contextual replies generated locally from a message or screenshot supplied by the user.
3. Intent controls such as Confirm, Decline and Ask a question, with optional tone and language overrides.

Example input: “Can we move the meeting to Friday?”
Example suggestions: “Friday works for me”, “What time?” and “Could we keep Thursday?”
These illustrate alternative intentions; the model must not assume which commitment the user wants to make.

### Context access and platform constraints

- A custom keyboard receives context from the active editable text field through `UITextDocumentProxy`.
  This does not expose the conversation displayed elsewhere in the host app. An empty reply field does
  not provide the incoming message. Full Access does not grant general screen-reading permission.
- Do not promise automatic reading of arbitrary apps as on macOS. Investigate explicit message sharing,
  user-initiated paste and screenshot sharing as context sources.
- For screenshots, first evaluate on-device OCR followed by a text-only model. This may avoid the cost
  of a vision model for ordinary chat screenshots; reading order and speaker attribution still need tests.
- Keyboard extensions have tighter resource constraints than the main app. A model fitting the phone's
  storage does not establish that it can run inside the keyboard process.
- Proposed architecture: generate in the containing app and pass a small, temporary set of results to
  the keyboard through the shared container. This is not proof that generation can run seamlessly while
  another app is foregrounded. Test app suspension, resource limits and stale-result handling explicitly.
- Background GPU processing is restricted. Apple's continued-processing APIs have capability and device
  requirements; they are not an unrestricted always-running inference service. Verify support on the
  actual device and OS before committing to a background architecture.

Sources: [Apple custom keyboard guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html),
[UITextDocumentProxy](https://developer.apple.com/documentation/uikit/uitextdocumentproxy),
[background tasks](https://developer.apple.com/documentation/backgroundtasks/),
[background GPU resource requirements](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtaskrequest/resources/gpu).

### Local model candidates

Start by evaluating **Qwen3-1.7B with 4-bit quantization and thinking disabled** for short responses.
This is a candidate, not a selected production dependency. A rough weight-storage estimate is around
1 GB; actual package size and runtime memory must be measured. Runtime also needs cache, activations
and framework allocations. Polish quality, multilingual replies, latency, temperature and battery use
have not been benchmarked on the owner's iPhone 17.

Also evaluate the on-device Apple Foundation Models API where available. Apple's published language list
checked on 2026-11-14 did not include Polish, so it must not be the only planned backend for Dictum.
Check model availability and supported locales at runtime; language support can change with OS releases.
Neither backend automatically receives the host app's screen content.

Sources: [Qwen3-1.7B model card](https://huggingface.co/Qwen/Qwen3-1.7B),
[Foundation Models language support](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models),
[Apple Intelligence requirements and languages](https://support.apple.com/en-us/121115),
[iPhone 17 specifications](https://www.apple.com/iphone-17/specs/).

### Tasks and acceptance criteria

- [ ] **REPLY-01 — Instant reply strip.** Provide localized quick replies and emoji without inference.
  Verify insertion at the caret, selected-text behavior, repeated taps and layout in both orientations.
  Do not infer the conversation language from an empty input field; offer a language choice.
- [ ] **REPLY-02 — Explicit context intake.** Prototype sharing or pasting a message and sharing a screenshot.
  Preview the context and selected language before generation. Test OCR with multiple speakers and mixed languages.
- [ ] **REPLY-03 — iPhone 17 model benchmark.** Compare Qwen's quantized runtime with the available on-device
  Apple model. Record cold/warm latency, time to three complete replies, peak memory, model disk size,
  Polish/English quality and sustained-use thermal behavior. Test alongside loaded speech models.
- [ ] **REPLY-04 — Execution feasibility.** Test foreground generation, returning to the host app,
  continued-processing availability, cancellation, suspension and keyboard termination. Choose the supported
  interaction based on measurements; keep explicit foreground generation as a fallback.
- [ ] **REPLY-05 — Contextual suggestions.** Return three short, distinct replies in the supplied conversation's
  language. Let the user choose intent or regenerate. Never invent personal facts, availability or prior actions.
- [ ] **REPLY-06 — Safe result delivery.** Bind suggestions to the supplied context and target editing session.
  Clear expired results, prevent insertion into a different conversation, support cancellation, and keep raw
  messages, screenshots and model output out of logs. Define temporary-data retention before implementation.
- [ ] **REPLY-07 — Device QA.** Test on the physical iPhone 17 and an iPad, in Dictum and external hosts,
  including offline mode, low-memory conditions, language changes and app switching. Report measured limits.

Recommended first slice: instant reply strip plus an explicit “share message or screenshot → generate
three replies → return and insert” flow. Automatic screen-aware suggestions remain an investigation,
not a promised capability.

## Additional product backlog

These proposals extend existing capabilities: Dictum already has a correction dictionary, local speech
recognition, macOS LLM cleanup, context mode and per-app prompts. Do not recreate those as new features.

### RECOVERY-01 — Reinsert the last dictation

Status: planned; proposed high priority.

- [ ] Keep the latest result temporarily in RAM and offer Reinsert or Copy when delivery fails.
- [ ] Define a short expiry, clear action and behavior when the target app changes.
- [ ] Preserve the existing no-persistent-transcription-history design.
- [ ] Investigate paste acknowledgment instead of relying only on a fixed clipboard restoration delay.

Inspiration: [Handy](https://github.com/cjpais/Handy) documents transcript recovery and an experimental
Reliable Paste mechanism. Dictum's proposed RAM-only recovery is an adaptation, not Handy's history design.

### PHRASES-01 — Spoken reusable phrases

Status: planned; proposed high priority.

- [ ] Expand distinctive spoken triggers into saved signatures, addresses, support replies and other templates.
- [ ] Extend the existing dictionary model where appropriate, while distinguishing word corrections from templates.
- [ ] Provide editing, collision detection, preview and import/export; evaluate consistent behavior on Mac and iOS.

Inspiration: [Wispr Flow snippets](https://docs.wisprflow.ai/articles/5784437944-create-and-use-snippets).

### MODES-01 — One-tap output modes

Status: planned.

- [ ] Expose Verbatim, Message, Email and List presets in a compact control, including the iOS keyboard.
- [ ] Reuse existing prompt infrastructure instead of adding a second formatting system.
- [ ] Distinguish mode selection from automatic per-app prompts and make the active mode visible.
- [ ] Gate iOS AI formatting on the local-inference feasibility work above.

Inspiration: [Superwhisper built-in modes](https://superwhisper.com/docs/modes/built-in)
and [mode configuration](https://superwhisper.com/docs/modes/modes).

### DICTIONARY-01 — Learn from corrections

Status: planned.

- [ ] Offer “Remember this spelling?” after an explicit correction, particularly for names and technical terms.
- [ ] Start with corrections made in a Dictum-owned interface; investigate external-app edits separately.
- [ ] Require a clear user choice before saving a new rule and make it editable and removable.
- [ ] Test capitalization, word boundaries and conflicts with phrase expansion.

Inspiration: [Wispr Flow dictionary and optional auto-learning](https://docs.wisprflow.ai/articles/4052411709-Teach-Flow-your-words-with-the-dictionary).

### IMPORT-01 — Transcribe shared recordings

Status: planned.

- [ ] Accept user-selected audio from Files, Voice Memos or a share workflow and transcribe locally.
- [ ] Build a production import interface; the existing Debug transcription harness is not a shipping import feature.
- [ ] Support progress, cancellation, long recordings and explicit copy/export of the result.
- [ ] Evaluate video audio extraction separately from the initial audio-only slice.

Inspiration: [Superwhisper file transcription](https://superwhisper.com/docs/get-started/transcribe-files).

## Keyboard parity follow-up

The gesture implementation shipped in TestFlight 0.11.0 (26111401). Research, simulator evidence and known
limitations are recorded in [iOS development and gesture QA](ios.md#apple-keyboard-gestures-research-2026-11-14).

### KEYBOARD-01 — Shift and space range selection

Status: requested parity gap; blocked on a supported host-selection mechanism, not implemented.
The owner explicitly reported that holding Shift, then holding Space and dragging left/right should
extend or shrink a text selection from its initial anchor. Space alone should move the insertion point.
The shipped trackpad only moves the insertion point and cancels pending modifier touches on activation.

- [ ] Establish a supported way for a keyboard extension to change the host's selection range before
  implementing the gesture. Rechecked the current documentation and installed UIKit SDK on 2026-11-14:
  `selectedText` is read-only and `adjustTextPosition` moves the insertion point, not a selection endpoint.
- [ ] If such a mechanism becomes available, cover anchor preservation, left/right reversal, shrinking
  through the anchor, both finger-release orders, cancellation and multiline text in external host apps.
- [ ] Keep this gap explicit in parity claims; an implementation only in Dictum's own editor would not
  fulfill the systemwide keyboard requirement.

`setMarkedText(_:selectedRange:)` inserts or replaces composition text; it is not a setter for a selection
over existing host text. Do not delete/reinsert the document to imitate selection, because that can change
formatting, undo history and application state.
Sources: [UITextDocumentProxy](https://developer.apple.com/documentation/uikit/uitextdocumentproxy)
and [read-only selectedText](https://developer.apple.com/documentation/uikit/uitextdocumentproxy/selectedtext).

#### Competitor implementation check

Checked on 2026-11-14 after the owner specifically suggested Dictus. This was source/documentation
research, not an installed-app gesture test.

- **Dictus iOS:** inspected commit `8804c3629741b9aebe9475e0b2103769eb969dc5`.
  Its [space hold handler](https://github.com/getdictus/dictus-ios/blob/8804c3629741b9aebe9475e0b2103769eb969dc5/DictusKeyboard/Vendored/Views/KeyboardView.swift#L918)
  creates a cursor controller. The controller emits integer movement, and the
  [bridge](https://github.com/getdictus/dictus-ios/blob/8804c3629741b9aebe9475e0b2103769eb969dc5/DictusKeyboard/DictusKeyboardBridge.swift#L337)
  calls `adjustTextPosition(byCharacterOffset:)`. No selection anchor or Shift-based range-extension
  path was found in that implementation. This confirms cursor movement, not the requested selection gesture.
- **KeyboardKit Pro:** its [proxy utilities](https://keyboardkit.com/features/proxy-utilities)
  advertise full-document context and custom proxies for editors inside the keyboard. Neither capability
  establishes a setter for the external host's selection. No documented solution for this gesture was found.
- **Microsoft SwiftKey:** [official cursor-control instructions](https://support.microsoft.com/en-au/swiftkey-keyboard/how-do-i-use-cursor-control-on-my-microsoft-swiftkey-keyboard)
  describe repositioning the cursor. They do not document Shift+space range selection on iOS.
- **Typefinity:** its [product page](https://typefinity.com/) advertises cursor arrow keys, which does not
  establish range-selection support. Its legacy tips page returned HTTP 410 during this check.

Conclusion: no verified competitor workaround was found. This is not proof that no workaround exists;
any future lead must demonstrate host-text selection on an ordinary iOS installation, distinguish it from
cursor movement or an internal editor, and preserve the original text and undo behavior.

#### Simulator experiments

On 2026-11-14, a separate iPad app and keyboard extension tested proxy selectors, responder actions
and marked-text rewriting. Rewriting did create a visible selection, but lost bold formatting,
collapsed the selection on unmark, replaced the entire composition on typing, and failed the undo
check. See [the experiment report](keyboard-selection-experiments.md) for reproducible steps and evidence.
The production gesture remains blocked; the destructive workaround is not enabled.

### Other follow-up tasks

- [ ] Complete dark-mode, physical-device, two-finger modifier and external-host QA.
- [ ] Review capitalization after moving the cursor back into a word.
- [ ] Refine glyph sizes, punctuation legends, bottom-row geometry and remaining phone layout differences.
- [ ] Scope independent autocorrection, prediction, smart punctuation and field-specific layouts as separate work.

Range selection, vertical movement by visual lines and unrestricted access to Apple's keyboard engine
must not be presented as solved. Public keyboard APIs constrain these features; see the linked iOS notes.

## Research scope

Research was used for product ideas, not copying implementations. The survey included commercial tools
Wispr Flow and Superwhisper and open-source projects [Handy](https://github.com/cjpais/Handy) and
[VoiceInk](https://github.com/Beingpax/VoiceInk). The concrete proposals above link to the sources that support
them. Model choice and performance remain subject to physical-device testing; no competitor benchmark
establishes Dictum performance on iPhone 17.
