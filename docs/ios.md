# Dictum for iOS

## Layout

- `macOS/`: existing Mac application, including its platform resources.
- `iOS/App/`: iPhone/iPad application, microphone session and local speech engine.
- `iOS/Keyboard/`: lightweight keyboard extension; no model or microphone runs here.
- `iOS/Resources/`: platform Info plists and App Group entitlements.
- `Shared/Keyboard/`: session protocol and atomic file mailbox, tested by `DictumTests/Keyboard/`.
- `Resources/`: shared icon, accent color, privacy manifest and English/Polish string catalogs.
- `project.yml`: source of truth for all three application/extension targets.

## Install on your iPhone

1. Run `xcodegen generate`, then open `Dictum.xcodeproj`.
2. Sign in to your paid Apple Developer account in Xcode Settings → Accounts.
3. Select scheme **DictumIOS** and your physical iPhone. Enable Developer Mode on the phone if requested.
4. In Signing & Capabilities, use team **Y5T33B6749** and automatic signing for both **DictumIOS** and
   **DictumKeyboard**. Both must have `group.com.dominikkrajcer.dictum` in App Groups.
   Xcode needs account access to register the two explicit bundle IDs and create matching profiles.
5. Build and run. No App Store or TestFlight upload is involved.

The display name and icon match Dictum on the Mac. The bundle identifiers are distinct:
`com.dominikkrajcer.dictum` and `com.dominikkrajcer.dictum.keyboard`.
The app shares its bundle identifier with the Mac app. Both iOS targets use the shared App Group
`group.com.dominikkrajcer.dictum`, with Apple's required `group.` prefix and no platform suffix.
A development installation expires when its provisioning profile expires; inspect the generated profile's
actual expiration rather than assuming a permanent installation. Renew by building from Xcode again.
Do not revoke or replace certificates used by other projects to resolve local account issues.

## Use

1. Open Dictum. The selected model prepares automatically, using cached files when present, and the app
   requests microphone access if needed. After permission is granted the microphone session starts automatically.
2. Add Dictum under Settings → General → Keyboard → Keyboards and enable Full Access. The keyboard icon in
   the app opens its Settings page. The main screen contains a model picker, model preparation details and a test text field. Each choice shows an
   approximate model size; the prepared model also shows allocated file size on this device and preparation time.
3. Tap the test field or open a field in another app. Select Dictum with the globe and tap the purple Dictum icon
   at the right end of the bottom row. Speak, then tap the red stop square in the same place.
   The keyboard inserts the result automatically into that same field. There is no separate Insert action. The
   icon also opens Dictum when no session is available. Recording has one stop control; no cancel button is shown.
4. The microphone icon in the app pauses/resumes the session: yellow when stopped, green when ready, orange while
   recording. Its accessible label/value communicates the same state without a duplicate status row. Switching models prepares the selected model and
   rearms automatically. The model choice is saved. Returning to the foreground rearms a stopped session unless
   you explicitly paused it.

Automatic delivery is scoped to the recording started by that keyboard in that document. Changing the target
field or leaving the keyboard cancels delivery; stale or unrelated results are acknowledged without insertion.
Each result is delivered at most once. Text in the test field is held in memory only.

The keyboard uses a three-row QWERTY layout, with Polish and other European letter variants available by holding
a letter. It includes number/symbol pages, a full local emoji browser, space, backspace, shift and return. Portrait geometry follows the supplied
system-keyboard reference: 43-point keys, 6-point horizontal gaps and 11-point row gaps. The header only appears for an actionable error;
there is no empty prediction-bar placeholder.
At 402 points, return is 45.5 points wide, matching backspace; space is approximately 188.7 points wide.
The narrower return transfers its entire recovered width to space, retaining the 44-point Dictum key. Dictum is aligned above the system microphone,
with the same 43-point height as the other keys and no additional trailing inset.
Holding backspace deletes once immediately, then repeats after 500 ms at 100 ms intervals. After 20
character repeats it switches to deleting one word every 200 ms; releasing resets the progression. Word
deletes include trailing spaces, preserve paragraph boundaries and treat composed emoji as one character.
Each operation is bounded to 64 characters, with single-character fallback when the host supplies no context. Releasing, dragging
outside the key or dismissing the keyboard stops repetition. A regression test first failed against single-tap behavior.
The emoji browser includes 1898 base emojis across eight categories, 48 persistent deduplicated recents, English
and Polish keyword search, and skin-tone preferences and per-emoji variants. Five-row lazy grids scroll horizontally
between categories; search results are bounded to 120 entries. Search uses the custom letter keys and routes deletion to
the query, preserving the host field. The pinned Emojibase 18.0.0 dataset is bundled offline with its MIT and
Unicode licenses, restricted to Emoji 15.1 for the iOS 18 deployment target. Localization metadata lives in
Localizable.xcstrings; the localization gate reads explicit references from EmojiCatalog.json.
Accented letters use a horizontal popup controlled by the original touch, including when the finger slides
outside the popup vertically. It selects on release, tracks upper/lower case and stays within keyboard edges.
Only while a popup needs space above the letter rows does the extension reserve the required inset, keeping keys in place.
The system keyboard input view supplies the translucent material; key fills use a calibrated translucent overlay.
The SwiftUI host ignores its own safe-area inset to avoid black strips.
Apple's predictive typing, swipe typing and autocorrection are not embedded. Switch back to Apple's keyboard
for those. The emoji browser is Dictum's implementation and uses the system's native emoji glyphs.

## iOS constraints

- iOS does not allow adding a custom button to Apple's keyboard or taking over its dictation microphone.
- The keyboard cannot record audio. The containing app opens an AVAudioEngine session in the foreground.
  `AVAudioApplication.setInputMuted(true)` system-mutes all app input while idle, transcribing or awaiting delivery.
  Start unmutes only after the recording file is ready; stop and discard mute again before closing the file.
  This is app-level input muting, not a hardware shutdown. The audio engine/session remains alive in the background
  and still consumes power. Completely stopping it requires reopening Dictum to start another recording.
- The dictation control sits inside the custom keyboard, after return. The system-owned bottom area
  cannot be overlaid. `hasDictationKey` declares custom dictation support, and the extension only supplies a globe
  when UIKit requests one, avoiding a duplicate switcher on devices with a system globe.
- Sessions stop on an audio interruption, when paused or when the engine stops. A recording is capped at
  three minutes. Background suspension, app termination and route changes can require returning to Dictum;
  the app rearms automatically in the foreground.
- The keyboard's Open Dictum link is a convenience; opening URLs from keyboard extensions depends on iOS.
  Opening Dictum manually is the fallback. On physical devices, the keyboard uses guarded private host discovery
  and a curated resume-URL catalogue to return automatically after microphone readiness. Unknown hosts stay in Dictum.
- Secure fields, phone-pad fields and apps rejecting keyboard extensions use the system keyboard.
- Only Ultra and v3 are integrated in this first iOS version. There is no LLM cleanup, cloud fallback,
  Nemotron or Whisper comparison runner on iOS yet.

## Privacy and storage

The keyboard reads the immediate preceding text only while deleting a word to locate its boundary.
That context is transient, is not logged or stored, and is never passed to the recognizer or sent over the network. Transcripts are passed through an atomic App Group file
and removed after acknowledgment, discard, session termination or one minute while the app is running.
Audio is written to an app-private temporary CAF file only during recording and deleted after processing or
cancellation. New launches remove leftover Dictum audio files and reset the mailbox after an interrupted run.
If iOS kills the process, temporary files may remain until that cleanup; no transcription history is maintained.
The mailbox is excluded from backup and protected until first unlock. Audio files use complete-unless-open
protection. Neither application code nor the keyboard logs speech, transcription or surrounding text.

## Verification

- `scripts/run.sh` and `scripts/test.sh` retain the existing macOS launch and unit-test behavior.
- `scripts/ios-build.sh` builds for a generic iOS Simulator; pass `--device` to build a signed device app.
- `DictumTests/Keyboard/` covers expired sessions, stale commands, recording identity, one-time command delivery,
  corrupt requests and transcript/mailbox deletion without microphone or downloaded models.
- Simulator checks verify installation, the setup screen and keyboard UI. Neural Engine performance, microphone
  continuity in other apps and signing must be verified on a physical iPhone.

Physical-device QA: prepare each model; deny and then grant microphone permission; dictate Polish in Dictum;
add/enable the keyboard and use it in Notes and T3 Code; cancel once; insert a result only once; wait for result
expiry; change audio route; interrupt with a call; force-quit Dictum; rearm; end the session and confirm the orange
indicator disappears. Verify that no text is inserted after cancellation and that an old result is never inserted
into another field. Repeat with system language Polish and without network after download. Verify automatic startup,
saved model selection, pause/resume and that changing the focused field during transcription never inserts into
the replacement field.

## Model preparation details

The model picker shows approximate sizes from the pinned FluidAudio export documentation: Ultra about 630 MB
and v3 about 480 MB. After preparation, allocated sizes are measured from the selected model cache, including
compiled files. The displayed size is storage, not RAM usage.

Preparation shows download, checking and compilation phases, an elapsed timer and the last completed duration.
FluidAudio 0.18 reports progress per package and gives downloading half of that operation; the UI scales that
portion to the current package's download percentage and labels it accordingly. Packages can restart the bar;
this is not an overall completion estimate. Loading/compilation use a moving horizontal bar without an invented
percentage or ETA. Cached loading still reports elapsed time and its final duration.

## Diagnosing a missing transcript

Use the app's test field with the Dictum keyboard to test the same automatic-insertion flow used in other apps.
An empty capture or empty recognition result returns to readiness without inserting text or showing an error.
Other keyboard notices expand to show their full text and include a close button. Dismissed notices remain hidden
across mailbox polling, and starting another dictation hides the previous notice. A genuinely new error is shown again.

With a trusted, unlocked physical iPhone connected, `scripts/ios-test.sh <UDID>` runs hosted tests that recognize
a bundled synthetic Polish fixture through Ultra and verify that microphone capture produces a readable,
nonempty file with a nonzero signal. Prepare the model and grant microphone access in the app first. The microphone
test briefly captures local audio, deletes the recording afterwards and never copies it off the phone. Model
preparation can download weights if absent. The main macOS test scheme excludes these device integration tests.

## Audio references and physical-device findings

The implementation was compared with these Swift iOS projects:

- [Dictus](https://github.com/getdictus/dictus-ios), MIT: native AVAudioEngine capture, system input muting while idle,
  keyboard IPC and session recovery; see `DictusApp/Audio/UnifiedAudioEngine.swift`. Dictum uses the public mute API
  rather than keeping an unmuted input outside recordings.
- [VivaDicta](https://github.com/n0an/VivaDicta), MIT: isolated recording services, AVAudioRecorder finalization and
  input routing; see `Modules/AudioRecording` and `Modules/AppGroup/.../RecordingAudioSession.swift`.
- [Ara](https://github.com/sebastiendb/Ara): public implementation of a foreground-armed continuous microphone
  with a file/notification bridge; see `Ara/Services/ContinuousMic.swift`.

On the connected iPhone 17, capture delivered a normal number of frames but only zero-valued samples while
screen sharing was active. With sharing turned off, the same controlled speaker-to-microphone test delivered
nonzero samples, recognized Polish speech and completed the app's start/stop/result/acknowledgment flow.
The independent AVAudioRecorder baseline also passed. Test directly on the unlocked physical phone when checking
microphone input. Apple explicitly documents that camera and microphone access are unavailable through
[iPhone Mirroring](https://support.apple.com/en-us/120421).

Apple documents that [app input muting](https://developer.apple.com/documentation/avfaudio/avaudioapplication/setinputmuted(_:))
mutes all input sources for this app and does not change the hardware mute state. Device regression tests assert
that idle and stopped input are muted, each recording unmutes, and full teardown stops the engine and clears the flag.

The recording engine is created after session activation, uses the negotiated tap format and explicitly closes
its audio file before transcription. The app reports missing signal rather than presenting it as a successful
empty dictation. Device integration tests play a short bundled synthetic Polish sentence through the speaker,
record locally, assert recognition and delete the temporary captures; no microphone recording leaves the phone.

## Keyboard reference review (2026-11-12)

Reviewed snapshots: Dictus `8804c36`, VivaDicta `88419b4`, Ara `e7a2cc5`. These are source findings,
not a comparative device test. No reference keyboard engine, dictionary or emoji catalog was copied.

- [Dictus input layer](https://github.com/getdictus/dictus-ios/blob/main/DictusKeyboard/Vendored/Views/KeyboardView.swift):
  dedicated UIKit touch handling, character/word backspace repeat, a space-bar cursor trackpad, key callouts and
  accent selection. The bridge also implements double-space punctuation and symbol-to-letter transitions.
- [Dictus emoji picker](https://github.com/getdictus/dictus-ios/blob/main/DictusKeyboard/Views/EmojiPickerView.swift):
  its own picker with categories, search and recents. It renders one category at a time to limit glyph-cache memory.
  This is a more complete custom picker, not an embedded Apple keyboard.
- [Dictus predictions](https://github.com/getdictus/dictus-ios/blob/main/DictusKeyboard/TextPrediction/TextPredictionEngine.swift):
  UITextChecker, bundled frequency/AOSP dictionaries and correction undo. The reviewed
  [language profiles](https://github.com/getdictus/dictus-ios/blob/main/DictusCore/Sources/DictusCore/SupportedLanguage.swift)
  are French, English, Spanish and German; Polish typing predictions require additional data and validation.
- [Dictus field policies](https://github.com/getdictus/dictus-ios/blob/main/DictusKeyboard/HostInputTraits.swift):
  respect host autocorrection/spell-checking flags and distinguish URL, email, numeric, password and OTP fields.
- [VivaDicta keyboard](https://github.com/n0an/VivaDicta/blob/main/VivaDictaKeyboard/KeyboardCustomView.swift):
  uses KeyboardKit for the keyboard and emoji UI and adds its own dictation controls. Its
  [repeatable control](https://github.com/n0an/VivaDicta/blob/main/VivaDictaKeyboard/Views/RepeatableButton.swift)
  handles held actions and transitions from character to word deletion. Adopting its keyboard would introduce
  a framework dependency, rather than only reusing a layout.
- [Ara emoji panel](https://github.com/sebastiendb/Ara/blob/main/AraKeyboard/EmojiPanelView.swift):
  a reusable UICollectionView with categories and recents, avoiding a button per catalog entry.

The emoji browser and horizontal accent selector were subsequently implemented in 0.11.0. Recommended next
work: space-bar cursor gestures, then typing conveniences such as caps lock, repeat acceleration and double-space
punctuation. Keep local dictation independent of that input layer. Polish autocorrection is a separate effort
and should respect programming/host field preferences rather than silently correcting code and identifiers.

## TestFlight distribution

`scripts/ios-testflight.sh` prepares a build number, archives the Release iOS app and exports an App Store Connect package. Add `--upload`
to upload instead. The archive is `build/ios-testflight/Dictum.xcarchive`; export options and delivery output are
in the same directory. The script defaults to internal TestFlight only, preserves the prepared build number
and never publishes a public App Store version or creates a macOS release/tag.

Use a valid Xcode Accounts session, or provide `DICTUM_ASC_KEY_PATH`, `DICTUM_ASC_KEY_ID` and
`DICTUM_ASC_ISSUER_ID` together. Pass only the path to the private `.p8` file; never add its contents to this repo.
A matching Apple Distribution certificate and App Store provisioning profiles are required for both the app and
keyboard. The versioned `iOS/Resources/TestFlightExportOptions.plist` uses local/manual signing with profiles
`Dictum Unified App Store` and `Dictum Unified Keyboard App Store`: this account cannot use cloud signing, even with its API key.
Both profiles are created through the App Store Connect API against the existing installed distribution
certificate. They must include the shared App Group and `beta-reports-active`. Cached device-development profiles
alone are sufficient to archive but do not authorize a TestFlight export. A regression test covers signing
policy, both profile mappings and internal-only distribution.
The script exports locally and checks both signatures and embedded provisioning profiles for the shared
App Group before allowing an upload. Xcode can silently remove this entitlement during export, so a successful
export alone is insufficient. The validator also checks identifiers and matching app/keyboard versions.

Create/check the one-time app record in App Store Connect with bundle ID `com.dominikkrajcer.dictum`. After
upload processing, assign the build to an internal group containing the owner's App Store Connect account, and
enable automatic distribution of new builds to that group. TestFlight builds expire after 90 days; subsequent
source changes require another upload. This is not automatic CI publishing.

### Version policy

`project.yml` stores one shared `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` for the app and keyboard.
The marketing version uses `MAJOR.MINOR.PATCH`: incompatible API changes increment major, new compatible
features increment minor, and compatible fixes increment patch. Apple requires the numeric core, so beta
labels and SemVer build metadata are not written into `CFBundleShortVersionString`.

TestFlight builds use BirthMinder/Shipyard's `date_counter` convention, `YYMMDDNN`, based on the local build
date. The first build on 2026-11-12 is `26111201`, the next is `26111202`; a new day resets the counter to 01.
The generator rejects counter overflow and a clock rollback that would repeat or lower the number. It
persists the number before archiving, so even a failed archive reserves it. Ordinary Debug builds do not
increment it. Apple's automatic renumbering is disabled.

Use `scripts/ios-testflight.sh --bump patch|minor|major` or `--version X.Y.Z` for an explicit semantic release;
without either, a new beta keeps the current marketing version. `python3 scripts/version.py` prepares only
the version/build settings; do not also run it before the archive script unless two increments are intended.
The existing macOS release workflow still overrides build numbers with its legacy timestamp for Sparkle
update ordering; changing that published sequence requires a separate migration.

The iOS store icon is an opaque 1024-pixel version of the existing Dictum logo; the Mac icon remains separate.
The app declares no non-exempt encryption (system HTTPS only), and its privacy manifest includes container-file
metadata used for cache/download integrity and displaying stored model sizes.

Distribution status on 2026-11-12: BirthMinder's existing release API key and issuer from its `shipyard.yaml`
authenticate successfully; the private key remains in BirthMinder's ignored release-skill secrets directory.
No BirthMinder files or app records were changed. Automatic export fails with `Cloud signing permission error`;
manual export succeeded for the previous `.ios` identifiers. That old IPA is superseded and must not be uploaded.
The owner registered `group.com.dominikkrajcer.dictum` and assigned it to the new app and keyboard identifiers.
Both store profiles have now been regenerated and their decoded entitlements confirm that exact group plus
`beta-reports-active`. The superseded `.ios` group was removed in the portal. The public API enables the
capability but does not associate groups; this required the owner's portal configuration. No distribution
certificate was revoked. Xcode's automatic provisioning request currently fails authentication; manual archive
signing uses the installed distribution certificate and the refreshed profile UUID for each target.
The verified `Dictum-verified.xcarchive` and `export-verified/Dictum.ipa` are `0.10.3 (26111201)`. Manual archive
and export succeeded, and the export validator confirmed the shared group in both signatures and profiles.
The earlier `Dictum-unified.xcarchive` and diagnostic IPA are superseded: their signatures lacked the shared
group, which `scripts/validate-ios-export.py` rejected as intended. Simulator launch with the new app identifier
and matching embedded keyboard metadata passed.

The owner created App Store Connect record `6834027438`, named `Dictum: Offline Dictation`, with English (U.S.)
as the primary locale and bundle ID `com.dominikkrajcer.dictum`. The chosen SKU convention is `dictum-prod`,
matching BirthMinder's `birthminder-prod`. English is the owner's default metadata language; Polish is an
additional localization. The verified IPA `0.10.3 (26111201)` was uploaded successfully through `altool`,
delivery and build ID `80a6cde9-e44e-47ee-9095-d2910805cffb`. The buildUploads API confirms `COMPLETE` with no
errors or warnings. The exact processed build is `VALID`, pre-release version `0.10.3`, build `26111201`,
audience `INTERNAL_ONLY`, encryption compliance satisfied, internal state `IN_BETA_TESTING`. It is assigned to
the `Internal` group and expires on 2027-02-10.
The internal-only group `Internal` exists with `hasAccessToAllBuilds=true`. Linking the account owner's existing
global beta tester failed with `STATE_ERROR: Tester(s) cannot be assigned`, but POSTing `betaTesters` with the
owner's email and the internal `betaGroups` relationship succeeded. The relationship `apps` is not allowed in
that create operation. The verified group now has exactly one tester, the account owner, in `INVITED` state;
Apple sent the invitation automatically when the build became available. No manual tester enrollment is
needed. The owner only needs to accept the invitation in TestFlight. No external group, public invitation
link or App Store submission was created.

Simulator QA on iOS 26.5 confirmed download progress, approximate picker sizes, cached load timing and measured
model storage, the compact keyboard layout, a single delete and held deletion (20 characters reduced to 13 in
a 1.1-second hold; no further deletion after release), and the simplified emoji toggle. The Simulator audio
engine could not start in this environment, so it is not a replacement for physical microphone testing.

Version 0.11.0 (26111202) adds the full emoji browser and touch-tracked accents. All 44 hosted tests passed,
including bilingual search, diacritic folding, persistent recent emoji, skin preferences, popup bounds and
selection outside the popup. Simulator QA confirmed the wider space bar, separated key backgrounds after
case changes, search using the custom letter keys without inserting the query into the host, animal-category
selection and a matching Recent entry. A recorded drag from the O key to a point below the popup inserted the
selected accent on release and removed the popup without leaving an idle header. The synthetic speech harness
also passed; this UI change does not replace physical microphone QA.

The 0.11.0 archive was signed with the refreshed profiles and its export passed the shared-group validator.
To supply the icon requested for the App Store Connect app list, this one export is App Store eligible and
is attached to the 0.11.0 draft, which remains PREPARE_FOR_SUBMISSION with manual release. Actual beta
distribution remains the owner-only Internal group; no public review or release is submitted. The default
archive script retains its internal-only export policy for subsequent development builds.

Delivery/build `9ec8a277-4a83-4a7b-a3fc-12e72ae315a8` completed successfully, with no warnings or errors. Apple
reports `VALID` and `IN_BETA_TESTING`; the Internal group includes both this build and the previous 0.10.3 build.
The app's formerly empty `appStoreIcon` relationship now references the 1024-pixel APP_STORE icon extracted from
the 0.11.0 build. Its actual CDN image was downloaded and visually verified as Dictum's purple microphone.
The English TestFlight notes describe the new keyboard features. Update to 0.11.0 (26111202) in TestFlight;
do not use the legacy `.ios` sideload, which the owner removed from the physical iPhone during diagnosis.


Build 26111203 retains version 0.11.0. The owner explicitly requested build-only increments for subsequent
TestFlight updates; do not bump the semantic version without a separate request.
The iOS app now lists both speech models with selection and installed state, and shows the installed version
and build in a centered footer. Simulator QA downloaded v3 once (495.2 MB allocated), retained Ultra
(642.9 MB allocated), switched Ultra → v3 from cache, and measured a 0.1-second cached v3 load. Actual sizes
vary with Core ML compilation and filesystem allocation. Outside taps dismiss editing; taps inside preserve
it. Two XCTest UI regressions cover dismissal and model selection, and 46 hosted Swift tests pass, including
the five-minute idle policy. The installed spells CLI rejects both required run/test forms, so scripts/run.sh
and scripts/test.sh were used as their project equivalents. Mac startup and the synthetic speech harness
passed. Simulator microphone activation fails in this environment; these checks do not replace physical audio QA.

The same 402 × 874-point iPhone 17 Pro Simulator at 3× captured native and Dictum keyboards. Connected-component
measurement found exactly equal bounding rectangles for all 28 keys in the first three rows. Both return keys
measure 279 × 129 pixels; the fourth row ends at y=2388 in both captures. Native space width is 574 pixels;
Dictum is 424, exactly 50 points shorter for the additional Dictum key and gap. The previous 12-point right
inset and five-point excess bottom padding were removed. The reproducible comparison script, raw screenshots,
measurements and interactive overlay are in build/qa/keyboard/. This measures geometry, not identity of every
rendered pixel: the visible difference image retains font, icon and space-label differences.

A completely stopped microphone is resumed by dictum://session in the containing app. A warm session mutes
input between recordings and shuts down after five minutes in the ready state; recording, transcription and
pending insertion do not consume that idle period. Returning automatically to an arbitrary host app has no
public iOS API (Apple DTS, developer.apple.com/forums/thread/826851). Dictus uses a private keyboard arbiter
resolver plus a catalogue of public resume URLs, including t3code://. That unsupported host detection was
not copied. A fixed, explicitly selected callback target is possible, but must not be mistaken for automatic
identification of whichever application currently hosts the keyboard.


## Local build 26111204

Version remains 0.11.0. This build has not been archived or uploaded: further TestFlight uploads require the
owner's explicit instruction. The Simulator-only `DictumKeyboardPreview` target provides the same host surface
for native/Dictum comparisons and an explicitly labelled recording-key component preview without audio. It is
not included in the production archive.

Long-pressing emoji opens up to ten frequently used emoji (nine at 375 points), ranked by persisted usage count
with recency as the tie breaker. Dragging outside the popup still selects by horizontal position; releasing inserts
the selection. A tap opens the full browser. Double-tapping Shift locks capitals; typing preserves that state.
The recording key uses an ordinary gray key surface and a red rounded rectangle.

The keyboard sends its BCP-47 primary language with each start command. The Polish layout declares pl-PL,
normalized to pl; older requests fall back to pl. The hint is captured for that recording and passed to both
FluidAudio decoders. FluidAudio 0.18's Language filter is script-aware: it reduces Latin/Cyrillic confusion,
not a Polish vocabulary constraint. It cannot distinguish Polish from other Latin-script languages and the SDK
can fall back to unfiltered decoding when no candidate matches. See the pinned
[TokenLanguageFilter documentation](https://github.com/FluidInference/FluidAudio/blob/v0.18.0/Documentation/ASR/TokenLanguageFilter.md).

The emoji face and nine category template masks were extracted from native iOS 26.5 Simulator keyboard screenshots
for the requested visual comparison. They are bundled images, with no private API or private font lookup at runtime.
The reference is OS-version-specific; the rest of the keyboard remains a custom implementation.

QA: 54 hosted Swift tests passed, including language normalization, backward-compatible mailbox delivery,
usage ranking/persistence, tone preference, caps locking, popup bounds and outside tracking. The Polish fixture
was recognized by both Ultra and v3 using pl, with no Cyrillic in the result. Simulator UI tests cover model
selection and focus dismissal. Physical microphone behavior was not retested for this local build.

Full native/custom PNGs, popup gesture videos and an interactive comparison are in build/qa/keyboard-build04/.
Static background samples match on both black and colored hosts; popup video frames are used for geometry only,
because video color conversion changes RGB values. Letter rendering, prediction support and the material area
above the accent popup still differ; the evidence is not a claim of complete pixel identity.


## iPad comparison follow-up

A fresh iPad Air 11-inch (M4) Simulator running iOS 27.2 was booted through agent-device and opened in the
Device panel. The same local build 0.11.0 (26111204) was installed without changing or uploading it. Native and
custom keyboards were captured in portrait at 820 by 1180 points, 2x, in the same comparison host. States include
letters, Shift off, Caps Lock, both numeric/symbol pages, accent selection, and a colored background.

The current iPad keyboard is not a native-equivalent tablet layout: it scales the phone's rows, omits Tab,
the separate Caps Lock and right Shift, auxiliary character labels, and the keyboard-dismiss key. iPad requires
the extension's input-mode switcher; the current either/or control consequently exposes the globe instead of
Dictum's emoji browser. The native iPad emoji browser has three rows rather than the phone's five. The native
iPad O popup uses two rows; Dictum retains the phone-style horizontal strip. These are observed gaps, not
features fixed by this comparison. Raw PNGs, gesture videos, measured key bounds and the interactive report
are in build/qa/keyboard-ipad/. The previous device discovery failure was resolved by booting the Simulator
in a separate agent-device preparation session before calling device_open.


## Build 26111205: tablet layout, touch dispatch and host return

The tablet keyboard now has its own four-row specification instead of stretching the phone layout. At 820
points, it uses approximately 55-point keys, 10-point horizontal gaps, 9-point row gaps, Tab, a separate Caps
Lock, left/right Shift and return in the second row. Numeral and symbol pages retain the tablet's top digit
row. Auxiliary characters support downward flicks. The bottom row retains dedicated emoji and globe keys;
the required extra globe shortens space by 54 points, while Dictum occupies the native microphone slot.
The keyboard-dismiss key calls UIInputViewController.dismissKeyboard. Undo/redo actions use the exposed
undo manager and stay disabled when the host does not expose one; the host's system assistant remains available.

The emoji browser uses three rows on iPad, with search in the category bar. Tablet accent choices use two rows
when necessary. The quick frequent-emoji popup still tracks outside its visible rectangle. UIKit keys are
rendered directly in the input controller. A single multi-touch dispatcher routes the gaps to the nearest key,
retains each touch until release, and reuses controls. A near-transparent black surface is necessary for remote
view-service hit testing to cover the gaps; it is not a flat keyboard background. SwiftUI renders the emoji and
popup layers. The touch changes apply to both phone and tablet.

Simulator checks reproduced a dropped gap tap before the change. After the change, 100 consecutive gap taps
inserted all 100 characters; twenty simultaneous five-finger gestures inserted exactly 100 characters, with
20 each of Q/W/E/R/T. These are controlled Simulator input checks, not physical typing-speed measurements.

Host return adapts Dictus's early arbiter activation and appearance-scoped pid evidence, with its MIT notice
in Resources/Licenses/Dictus.txt. Missing selectors and Objective-C exceptions fail to no host; evidence is
cleared on every appearance to avoid trusting a reused process identifier. No guessed application is opened.
Only curated resume schemes are accepted, including T3 Code, Notes, Messages, Mail, Reminders, WhatsApp,
ChatGPT and Slack. Build 26111206 expands this catalogue; see the current host catalogue below.
Activation opens Dictum, prepares/resumes its microphone session, then returns once readiness is confirmed.
Recording starts from the keyboard after returning. New activation requests cancel older pending returns.
A backgrounded app, failed audio activation, unknown host or preparation timeout never forces a return.

The private host-discovery path is disabled on the Simulator, whose keyboard/window behavior is not a
substitute for a physical-device test of these APIs. The physical path has an unsigned iPhoneOS build check;
full microphone-plus-return verification still requires an unlocked physical iPhone. The shared routing tests
check readiness gating, allowed destinations, unknown/duplicate host rejection and expiry of pid evidence.
Version remains 0.11.0, build 26111205. No archive or TestFlight upload is authorized by these local changes.

Final build 26111205 verification: all 61 hosted Swift tests in 23 suites passed; both UI tests passed on
iPad Air (iOS 27.2) and iPhone 17 Pro (iOS 26.5). The first three portrait rows have exactly equal bounding
rectangles for all 34 native and Dictum keys in original @2x screenshots. The comparison includes letters,
123, symbols, Shift, Caps Lock, accents, emoji, landscape and a colored host background. Holding delete
removed multiple characters, a downward Q flick inserted 1, and emoji search kept its query outside the
host editor. Tapping the inactive dictation key opened Dictum and began preparation. No physical return or
audio result is claimed. Source screenshots, recordings, measurements and an interactive comparison are
under build/qa/keyboard-build05/. The installed spells CLI still rejects `spells run` without a spell name
and has no `test` subcommand; scripts/run.sh and scripts/test.sh provided the successful launch/test gates.

## Build 26111206: communication and AI host catalogue

The keyboard now resolves 46 bundle identifiers through KeyboardHostCatalog. The catalogue is adapted from
Dictus commit 8804c36, which inherits VivaDicta's host mapping. VivaDicta commit 88419b4 supplies the Claude
entry and Microsoft 365 Copilot universal link. Both MIT notices ship in Resources/Licenses. The lookup is
static and does not enumerate installed apps or add canOpenURL probes.

Custom app schemes cover T3 Code, Notes, Messages, Mail, Reminders, WhatsApp, WhatsApp Business, Telegram
(both published identifiers), Swiftgram, Nicegram, Signal, Messenger, Discord, Teams, Slack, Viber, LINE,
WeChat, Threema, Mattermost, Element X, KakaoTalk, Beeper, Facebook, Instagram, Snapchat, Threads, X, Reddit,
LinkedIn, Gmail, Outlook, Spark, ChatGPT, Claude, Gemini, Perplexity, Grok and Monica.

Google Chat, Meta AI, Kimi, international Qwen, NotebookLM and Microsoft 365 Copilot use inherited universal
links. These are opened with universalLinksOnly so a failed app handoff stays in Dictum rather than opening
Safari. The Microsoft 365 mapping is not a claim about the standalone Copilot app. App landing pages may
replace the previous navigation, and user link preferences can prevent the handoff.

Claude is enabled at the user's explicit request despite Dictus's device test showing that claude:// starts
a new chat. This is app reopening, not verified preservation of the previous Claude conversation. DeepSeek,
standalone Copilot and Poe remain unmapped: the reference catalogue supplies no usable app-specific target
for them. Unknown hosts and share extensions retain manual return rather than guessing a destination.

Most additions are inherited mappings, not new physical-device measurements. Dictus marks LINE and
KakaoTalk as corroborated, and Beeper as inferred from its desktop scheme. Regression tests cover activation
round trips for the six requested apps and Telegram's second identifier, rejection of lookalike hosts/share
extensions, and distinct WhatsApp/Telegram-client targets. The microphone readiness gate is unchanged.
Version remains 0.11.0. This is a local build; no TestFlight upload is authorized.

Verification for build 26111206: the pre-change regression run failed with missing activation routes and
messaging variants. After the implementation, all 64 Swift tests in 24 suites passed. The macOS launch
check and generic iOS Simulator build passed; SwiftLint, comment/nesting, localization, log-privacy and diff
checks passed. Dictum QA launch logs show the event tap enabled and model warmup complete. These gates
verify routing logic and compilation, not third-party navigation preservation or microphone activation on
a physical iPhone. The installed spells CLI remains incompatible; project run/test scripts supplied the gates.

## Build 26111206 distribution

Uploaded on 2026-11-12 with delivery ID f4668bd6-7621-421c-818a-fcdf9320f54f. Release archive, manual export,
application/keyboard signatures, matching versions and shared App Group entitlements all passed validation.
Apple's transient HTTP 500 during finalization recovered within the same upload; altool reported success.
The last API observation is PROCESSING with no errors or warnings, not yet a VALID processed build.
The existing Internal group has automatic access to all builds; its single existing tester is INSTALLED.
No tester was created or invited again. Build processing and appearance in TestFlight remain Apple's pending
step. Nothing was submitted for public App Store review. Desktop additions and measurements are documented
separately in [the M4 ASR benchmark](asr-benchmark.md); the semantic version remains 0.11.0.

## Build 26111301: successful TestFlight retry

On 2026-11-13 the previous build 26111206 was still PROCESSING although all three uploaded assets were
COMPLETE with no errors. A fresh archive/export retained semantic version 0.11.0 and advanced only the
BirthMinder-style date counter to 26111301. Signatures, matching app/keyboard versions and App Group
entitlements passed validation. Delivery 79d7a600-7ea1-4022-8868-740d5c25c21d uploaded successfully and
processed as VALID / IN_BETA_TESTING, with autoNotifyEnabled=true and no errors or warnings. The Internal
group's build relationship explicitly includes this delivery. No new tester was created and no public App
Store submission was made. Build 26111206 remains pending but is superseded by 26111301.

## Phone vertical key-plane alignment

The user's 920x2000 iPhone captures show the Dictum row tops at 1352/1476/1600/1723 px versus Apple's
1368/1492/1616/1739 px: every row is 16 px higher (about 7 pt if the logical width is 402 pt). The iOS 26.5
Simulator did not reproduce this physical-device offset; it already placed the key rows at Apple's baseline.

The phone plane now uses the actual input-view bounds to consume surplus container height below its requested
top inset. For a 216 pt plane in a 223 pt container its origin is 7 pt, including when an error/accent/search
header is present. Matching-height containers retain zero offset, undersized containers do not move upward,
and iPad placement stays at its previous top inset. The physical cause is inferred rather than measured;
confirmation on the user's iPhone is still required. No fixed device-wide seven-point translation is applied.

The regression test failed on both plain and header-bearing surplus-height cases before the change. All 67
Swift tests then passed, as did the iOS Simulator build, SwiftLint, localization and privacy gates. Fresh
Simulator PNGs show identical space-row bounds at y=2259...2387 px (@3x); the Q-row antialiasing edge differs
by one pixel. Space insertion and Return were exercised in the preview host. Source PNGs, measurements and
an interactive comparison are in build/qa/keyboard-origin-20261113/. This is local QA, not an updated TestFlight
build or proof that the physical offset is resolved. The installed spells CLI remains incompatible; the project
run/test scripts provided successful launch/test gates, and Dictum QA launch logs show successful warmup.

## Compact phone Return

At the user's request the phone Return now uses the same modifier width as backspace, with the recovered
width assigned to space. At 402 pt, both Return and backspace are 45.5 pt wide and space is 188.668 pt.
The tablet slot specification is untouched; its 820 pt portrait Return remains 116.5 pt. Existing status,
heights, gaps and Dictum placement remain intact. The phone metrics helper matches the rendered plane.

Verification: all 67 existing Swift tests, macOS launch, generic iOS Simulator build and static checks passed.
A geometry smoke check confirmed equal Return/backspace sizes and the unchanged tablet Return. On the
Simulator, tapping x=280 in the widened space inserted a space (host field value Q followed by a space);
tapping the new Return center submitted the preview text field. This is a local change, not a TestFlight upload.


## Build 26111302

The next internal TestFlight package retains semantic version 0.11.0 and uses build 26111302. It includes
the iPhone bottom-row alignment and wider space key, silent handling of empty recordings/results, and
full-height dismissible keyboard errors that stay dismissed across polling and clear on retry. The iPad
key layout remains unchanged by these final phone adjustments. Quality-gate cleanup only extracts small
keyboard rendering helpers and diagnostic entry points without changing their behavior.


## Keyboard feedback

The extension uses a UIInputView that adopts UIInputViewAudioFeedback and calls UIDevice.playInputClick
for letter/modifier presses, emoji insertion and each repeat-deletion operation. iOS controls whether
keyboard clicks are audible, including its keyboard-feedback and silent-mode settings; no custom audio
session or bundled sound bypasses those settings. The recording key retains its key dimensions and uses
a centered 16-by-16-point red stop symbol with four-point rounded corners.

The repeat timings are Dictum's explicit policy, not an undocumented Apple API contract. A direct timing
comparison on the Simulator could not complete because its text-entry runner timed out after a read-back
mismatch; unit tests cover the transition, word boundaries, selection fallback and release cancellation.


## Foreground activation before returning to the host

Automatic return waits for an active Dictum scene before starting microphone activation, then waits
again after activation and checks that the microphone session remains ready. Each foreground wait is
bounded to ten seconds. Cancellation prevents stale requests from starting audio or returning to an
older host. The app's normal automatic activation also requires a foreground-active scene. This avoids
a one-shot application-state check discarding a return while an iPad window or permission dialog is
still transitioning. It does not change the PID-matched host resolver or the allowed return URL catalogue.

The host resolver is disabled in Simulator builds; unit tests exercise delayed scene activation,
cancellation, timeout, readiness loss and exactly-once return. End-to-end host discovery and T3 Code
return on physical iPhone/iPad still require device verification; private host APIs are best effort.
