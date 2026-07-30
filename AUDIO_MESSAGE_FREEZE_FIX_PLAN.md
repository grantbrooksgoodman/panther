# Fix Plan: Audio-Message Send Freeze / Post-Relaunch Instability

## Background (read first)

Sending an audio message (or the outbox auto-retrying one) can freeze the app: taps
register but perform no actions, presented sheets stay empty, and the app eventually
dies. Relaunches are unstable because the outbox re-enters the same pipeline on
launch, on connectivity restore, and on every foreground
(`Sources/Bundle/Delegates/AppDelegate.swift:77`,
`Sources/Bundle/Delegates/SceneDelegate.swift:92`).

Root cause: commit `b9890bb` removed the global gate that serialized
`AVSpeechSynthesizer.write` and moved synthesis onto per-call synthesizers running
directly on Swift Concurrency cooperative-pool threads, fanned out one-per-recipient-
language by `MessageSessionService.sendAudioMessage`
(`Sources/Modules/Session/Entity/Services/MessageSessionService.swift:91`). The
failure chain:

1. `AVSpeechSynthesizer.write(_:toBufferCallback:)` is invoked on a cooperative-pool
   thread (`Sources/Modules/Common/Services/Sources/Audio/TextToSpeechService.swift:151`).
   If the shared system TTS daemon stalls, the call blocks that pool thread
   indefinitely. The pool has only ~CPU-count threads; each wedged call permanently
   removes one, and once the pool is exhausted **every** `async` task in the app
   stops running while the main run loop stays alive — the exact observed symptoms.
2. When the 10-second `Timeout` fires, the continuation throws and `getAudioFile`
   returns, deallocating the synthesizer **mid-synthesis** (the
   `defer { withExtendedLifetime(avSpeechSynthesizer) {} }` at
   `TextToSpeechService.swift:130` only lasts until the throw). Deallocating a
   synthesizer with an active write session is what poisons the TTS daemon in the
   first place, and the buffer callback keeps mutating captured locals afterward.
3. The callback state (`output`, `timeout`, `didComplete` at
   `TextToSpeechService.swift:132-140`) is mutated from the TTS callback queue and
   the timeout's thread with no synchronization — a data race.
4. `TranscriptionService.transcribeAudioFile` has no timeout
   (`Sources/Modules/Common/Services/Sources/Audio/TranscriptionService.swift:64-81`),
   so a recognizer that never delivers a final result hangs the send forever. Every
   outbox retry re-runs transcription because the transcription is not persisted.
5. `AVSpeechSynthesisVoice.speechVoices()` is first touched concurrently from the
   per-language task-group children (via `isTextToSpeechSupported` /
   `highestQualityVoice`); the first call is a seconds-slow XPC fetch that is unsafe
   and slow under concurrent first access.

## Hard constraints

- **Do NOT reinstate serialization of `AVSpeechSynthesizer.write`.** Do not add a
  global width-1 gate around synthesis. Per-language syntheses must still be able to
  run concurrently (a bounded cap with a degrade-on-failure breaker is fine; see
  Change 2).
- Do not write tests or add a test target.
- All changes are in the Panther repo. Do not modify AppSubsystem, Translator, or
  networking. `LockIsolated` and `Timeout` come from `AppSubsystem` and are already
  used throughout this codebase — reuse them.
- Preserve existing public behavior of the send pipeline: same method signatures on
  `TextToSpeechService.readToFile`, same typed `throws(Exception)` conventions, same
  per-call unique output directories (`tts-<UUID>/<languageCode>-output.m4a`), same
  caches (`_TextToSpeechServiceCache`, `_TranscriptionServiceCache`).

---

## Change 1 — Isolate synthesis from the cooperative pool and make sessions cancellable

**File:** `Sources/Modules/Common/Services/Sources/Audio/TextToSpeechService.swift`

Rework `getAudioFile(from:languageCode:)` (currently lines 101-217):

1. **Introduce a session object** (private final class, `@unchecked Sendable`) that
   owns all per-synthesis state behind a single `LockIsolated` state box:
   - the `AVSpeechSynthesizer` instance,
   - the lazily created `AVAudioFile` output,
   - the output directory / file URL,
   - the `Timeout`,
   - a completion flag replacing the current `didComplete` / `canComplete` locals,
   - the checked continuation (resume-at-most-once semantics enforced inside
     `LockIsolated.withValue`).

   All reads/writes of this state from the buffer callback, the timeout callback,
   and the initiating code must go through the lock. This removes the data race in
   item 3 of the background section.

2. **Invoke `write` off the cooperative pool.** Create the synthesizer and call
   `synthesizer.write(utterance)` from a dedicated GCD queue, e.g.
   `DispatchQueue(label: "com.neotechnica.panther.tts-write", qos: .userInitiated)`
   — dispatch with `.async` from within the `withCheckedThrowingContinuation` body.
   The awaiting task then holds no thread; if a `write` call ever blocks, it blocks
   a replaceable GCD worker thread, not a cooperative-pool thread. This is the
   change that makes an app-wide freeze structurally impossible from this path.
   Note: the buffer callback itself already arrives on an internal AVFAudio queue;
   only the *initiating* `write` call needs to move.

3. **Never abandon a live session.** Replace the current timeout behavior:
   - On timeout (keep 10 seconds): mark the session failed, resume the continuation
     with `Exception.timedOut`, call `synthesizer.stopSpeaking(at: .immediate)`
     **on the dedicated queue** (not on the caller's thread and not on main), and
     move the session into a retention registry instead of letting it deallocate.
   - **Retention registry:** a private `static let` `LockIsolated` dictionary
     (keyed by `ObjectIdentifier` or a UUID) holding failed-but-live sessions. A
     session is removed (and its synthesizer/file finally released) when either
     (a) its buffer callback delivers the terminal zero-length buffer, or
     (b) a grace-period `Timeout` (e.g. 15 seconds after cancellation) fires —
     whichever comes first. This guarantees no synthesizer is ever deallocated with
     an active write session.
   - Output-directory cleanup on the failure path must happen at *release* time
     (when the session leaves the registry), not at throw time — the callback may
     still be writing to the file until the session ends.

4. **Success path is unchanged in behavior:** on the zero-length terminal buffer,
   release the `AVAudioFile` reference first (this finalizes the M4A container —
   keep the existing comment/invariant that the URL must not escape before then),
   then resume the continuation with the file URL.

5. The `@Dependency(\.avSpeechSynthesizer)` shared synthesizer is used elsewhere for
   spoken playback only; leave it and its call sites alone (see optional Change 6).

## Change 2 — Bounded concurrency with a degrade-on-failure breaker (not serialization)

**File:** same (`TextToSpeechService.swift`), new private type.

Add a small global limiter, e.g. `private actor SynthesisThrottle` with
`static let shared`:

- Normal width: **3** concurrent syntheses (typical sends have 1-2 recipient
  languages, so this costs nothing in practice while bounding daemon pressure in
  group chats).
- Breaker: when any synthesis times out, drop the width to **1** for the next
  60 seconds (store the last-trip `Date`; restore width 3 once the window passes).
  A wedge-prone daemon then gets gentle traffic instead of concurrent traffic,
  while the healthy path keeps full parallelism.
- Implement as an async `acquire()`/`release()` pair (continuation queue inside the
  actor, like the removed `TextToSpeechWriteGate` but with width > 1 and the
  breaker). Wrap the body of `getAudioFile` in it. Ensure `release()` runs on every
  exit path, including timeout.

## Change 3 — Prewarm the voice catalog at launch

**File:** `Sources/Application.swift` (next to the existing
`networking.database.prewarm()` / `networking.storage.prewarm()` calls at lines
127-128).

Add a fire-and-forget background task (match the codebase's existing
`Task.background` idiom) that calls `_ = AVSpeechSynthesisVoice.speechVoices()`
once. Import `AVFAudio` if not already imported. This moves the seconds-slow,
concurrency-unsafe first fetch of the voice catalog off the send path entirely.
Do not gate send-path calls on it having finished — after the first call the
system caches the catalog, and the existing per-language caches in
`_TextToSpeechServiceCache` / `_TranscriptionServiceCache` stay as they are.

## Change 4 — Timeout for file transcription

**File:** `Sources/Modules/Common/Services/Sources/Audio/TranscriptionService.swift`

In `transcribeAudioFile(at:languageCode:)` (lines 24-92):

- Keep a reference to the `SFSpeechRecognitionTask` returned by
  `recognizer.recognitionTask(with:)` (currently discarded).
- Replace the `didComplete` / `canComplete` local-var pattern with a `LockIsolated`
  completion flag (same race-safety rationale as Change 1).
- Add a `Timeout` (suggest 30 seconds — file transcription of a long voice note is
  legitimately slow; do not go lower than 20) that, if it fires first: cancels the
  recognition task via `task.cancel()`, then resumes the continuation throwing
  `Exception.timedOut(metadata:)`.
- On normal completion, cancel the timeout.

The failure now surfaces to `MessageSessionService.sendAudioMessage`, which already
propagates it; `MessageDeliveryService` marks the outbox entry failed and the UI
unsticks. That is the desired behavior — no additional handling needed.

## Change 5 — Persist the transcription on outbox entries so retries skip re-transcription

**Files:**
- `Sources/Modules/Session/State/Models/OutboxEntry.swift`
- `Sources/Modules/Content/User/Services/MessageDeliveryService.swift`
- `Sources/Modules/Session/State/Services/MessageOutboxService+Retry.swift`

1. `OutboxEntry`: add a new **optional stored property** `var transcription: String?`
   (top-level on the struct — do **not** add an associated value to
   `Payload.audio`, which would break decoding of already-persisted entries;
   synthesized `Codable` handles a missing optional field in old data
   automatically).
2. `MessageDeliveryService.sendAudioMessage(_:transcription:)` (entry construction
   around line 112): populate `transcription:` on the audio `OutboxEntry` from the
   method's `transcription` parameter. Leave the media/text entry constructions
   passing `nil` (or rely on a `= nil` default — match however the memberwise init
   shakes out; keep alphabetical/property-order conventions of the file).
3. `MessageOutboxService+Retry.swift`:
   - `sendPayload` (line 112): add a `transcription: String?` parameter and, in the
     `.audio` case, pass it through to
     `clientSession.entity.message.sendAudioMessage(_:presetID:transcription:toUsers:inConversation:)`
     — the parameter already exists there and already skips re-transcription when
     the string is non-blank (`MessageSessionService.swift:53-59`).
   - `retry(entryID:)` (line 82): pass `entry.transcription` into `sendPayload`.

No schema/network changes: `OutboxEntry` is local-only persisted state.

## Change 6 (optional hardening — do only if trivial) — Guard shared-synthesizer stops

**File:** `Sources/Modules/Content/User/Services/ChatPageView/Sources/InputBar/Sources/InputBarActionHandlerService.swift`

`didPressRecordButton` (line 106) and `didPressSendButton` (line 178) call
`avSpeechSynthesizer.stopSpeaking(at: .immediate)` on the main thread against the
shared playback synthesizer. Guard each call with
`guard avSpeechSynthesizer.isSpeaking else { ... }` so the XPC round-trip is skipped
in the common case where nothing is being spoken. Do not restructure anything else
in this file.

---

## What NOT to do

- No global serialization of TTS writes (see Hard constraints).
- No tests, no test target.
- No changes to AppSubsystem, Translator, or networking packages.
- No changes to `RecordingService`, `LiveTranscriptionSession`, the upload path
  (`AudioMessageService.uploadAudioComponents` / `forEachConcurrently`), or the
  translation fan-out in `MessageSessionService` — they are not implicated in the
  freeze and were recently reworked deliberately.
- Do not remove or bypass the outbox auto-retry triggers; once the pipeline can no
  longer wedge, they are correct as-is.

## Verification (manual, no tests)

1. Build the app target (`Panther.xcodeproj`, scheme Panther) for an iOS Simulator
   destination; the build must succeed with no new warnings in the touched files.
2. Code-review invariants to confirm by inspection before finishing:
   - No call path invokes `AVSpeechSynthesizer.write` from a cooperative-pool
     thread (it must be dispatched to the dedicated queue).
   - No exit path of `getAudioFile` can deallocate a synthesizer whose session has
     not terminated (throw paths must route the session through the retention
     registry).
   - Every `acquire()` on the throttle has a matching `release()` on every exit
     path, including timeout and thrown errors.
   - The continuations in both `getAudioFile` and `transcribeAudioFile` are resumed
     exactly once under their respective locks.
   - `OutboxEntry` decoding of a payload persisted *before* this change (no
     `transcription` key) still succeeds.
3. If a simulator run is possible: send an audio message in a conversation whose
   recipient has a different language; confirm the message sends, the app stays
   responsive during the send, and the TTS output plays for the recipient-language
   component. Then force a TTS failure (e.g. temporarily set the synthesis timeout
   to 1ms), send again, and confirm: the send fails cleanly with a toast/log, the
   outbox entry is marked failed, the UI unsticks, and — critically — subsequent
   unrelated async UI (opening settings, tapping the chat header) still works.
