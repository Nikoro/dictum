# External keyboard selection experiments

Date: 2026-11-14. Related task: [KEYBOARD-01](roadmap.md#keyboard-01--shift-and-space-range-selection).

## Result

A composition-based workaround can produce a visible selection in an external host UITextView,
but it failed formatting preservation, selection persistence, replacement and undo checks.
Do not ship it as Shift+space parity. No production keyboard code was changed for these experiments.
This is evidence against the tested approaches, not proof that every possible workaround is impossible.

## Research

- Apple's [UITextDocumentProxy](https://developer.apple.com/documentation/uikit/uitextdocumentproxy)
  exposes cursor movement and a read-only selectedText, without a public host selection setter.
- [setMarkedText(_:selectedRange:)](https://developer.apple.com/documentation/uikit/uitextdocumentproxy/setmarkedtext(_:selectedrange:))
  selects inside newly supplied composition text. It does not directly select an existing host range.
- [Handling text interactions in custom keyboards](https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards)
  explains composition and committing it with unmarkText.
- The [competitor source review](roadmap.md#competitor-implementation-check) found cursor movement in
  Dictus, but no Shift-based range extension. KeyboardKit, SwiftKey and Typefinity documentation did
  not establish an external-host selection workaround.
- [Keytao's iOS implementation notes](https://github.com/xkinput/keytao-app/blob/main/crates/keytao-ios-ime/IMPL.md)
  also list selection extension and select-all among unsupported actions under the proxy API.

## Test setup

A separate UIKit app (`com.dominikkrajcer.selectionlab`) and real keyboard extension
(`com.dominikkrajcer.selectionlab.keyboard`) were built and installed on **Dictum iPad Gesture QA**,
iPad Air 5 simulator, iOS 27.2. All UI was driven through the T3-bound agent-device command.
The keyboard runs across the extension boundary; it does not receive a direct reference to the host editor.

The host uses a UITextView with rich-text editing enabled and the synthetic string `Alpha BETA gamma`.
`BETA` is bold. Initial caret is UTF-16 range `{10, 0}`. Reset clears undo history. A host-side timer
reports selectedRange, markedTextRange, string equality, bold character count and canUndo.
A host-only button sets `{6, 4}` as a positive control, without modifying the text.

Local reproducible sources and screenshots are retained in `build/qa/selection-lab/` (ignored build
artifacts, not committed). Generate with `xcodegen generate`, then build the SelectionLab scheme for
iphonesimulator. Enable the Selection Lab keyboard in Settings and select it with the globe menu.
The first launch needed a UIScene lifecycle for this SDK. Early screenshots 01–05 have black fixture
text on a dark background; subsequent screenshots correct the fixture foreground color. Host metrics
and AX text were available throughout.

## Observed results

| Experiment | Host result | Interpretation |
| --- | --- | --- |
| Host selects BETA | `{6,4}`, no marked text, 4 bold characters, no undo change | Positive control for an ordinary selection |
| Proxy protocol and selector inspection | Not UITextInput; none of select:, selectAll:, moveLeftAndModifySelection:, setSelectedTextRange:, setSelectionRange: supported | No discovered direct selection entry point; inspection only, no private setters invoked |
| Standard responder selectAll: | Target nil, proxy responds false; range stays `{10,0}` | Responder action did not reach host |
| adjustTextPosition(-3) | `{7,0}`, unchanged text and formatting | Cursor baseline works, no range extension |
| setMarkedText("xyz", {0,3}) | `Alpha BETAxyz gamma`, range `{10,3}`, marked true | Selects inserted text, changes document |
| Delete preceding 6 characters, setMarkedText("a BETA", {0,6}) | Original string restored, range `{4,6}`, marked true; **bold count 4 → 0**, canUndo true | Visible selection is possible, but existing content is rewritten |
| Change same composition to selectedRange `{2,2}` | Host `{6,2}`, original string, marked true | Selection can shrink inside composition |
| unmarkText() after the two-character selection | Host `{6,0}`, marked false | Selection collapses; proxy's delayed selectedCount briefly still reported 2 |
| insertText("X") after unmark | `Alpha XBETA gamma` | Inserts at caret rather than replacing BE |
| Fresh rewrite, select two, insertText("X") without unmark | `AlphX gamma` | Replaces entire six-character composition, not just selected BE |
| Host Undo after previous sequence | `AllphX gamma`, range `{0,2}` | Did not restore original fixture; undo sequence is unsuitable |

The final replacement test would produce `Alpha XTA gamma` for an ordinary selection of BE. Instead,
the composition region was replaced. This difference prevents treating the visible highlight as normal
host selection. The undo observation is specific to this tested sequence and SDK, not a claim about all editors.

## Evidence and remaining scope

Screenshots: `build/qa/selection-lab/evidence/01-api.png` through `09-undo.png`.
`06-host-control.png` and `07-rewrite-visible.png` show the formatting/undo difference clearly.
`08-replace-composition.png` and `09-undo.png` capture the replacement and undo failures.

This was a mechanism experiment, not a completed Shift+space gesture implementation. It did not test
physical multitouch, every host editor, WebKit inputs, secure fields or physical devices. A supported
solution must pass those checks and preserve text, formatting, undo and selection after release.
An internal Dictum editor can control its own UITextInput selection, but that does not solve arbitrary
external apps. No hidden rewrite fallback is enabled in the shipping keyboard.

## Validation

The isolated app and extension built successfully with xcodebuild and were manually exercised above.
The dictum-qa skill was consulted; its macOS audio and event-tap scenarios do not apply to this isolated
iPad mechanism probe. Production Dictum code is unchanged. Required command attempts failed because
this installed spells CLI is incompatible: `spells run` reports `run: missing spell name`; `spells test`
reports `unknown subcommand test`. These are not passing test results.
