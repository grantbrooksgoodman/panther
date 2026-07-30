# Message Send Throughput — Implementation Plan

## Objective

Reduce the time from send-press to **Delivered** for text, audio, and media messages.

"Delivered" flips when the atomic fan-out commit in `Conversation.willWrite(_:forKey:updating:)`
(`Sources/Modules/Networking/Sources/Conversation/RemotelyUpdatable/Conversation+RemotelyUpdatable.swift`)
— or `ConversationService.createConversation` for a first message — succeeds and the outbox
entry is removed. Everything upstream of that commit is the critical path. The commit itself is
already a single atomic RTDB write and push notifications are already backgrounded; do not
restructure those. All work below removes or hides latency **before** the commit.

## Baseline (what the audit found)

Per recipient language, a text send with novel text currently pays this serial chain inside
`HostedTranslationService.translate` (Networking package):

1. Hosted-archive lookup: RTDB `getValues` at `translations/<pair>/<hash>` — almost always a
   miss for chat text; the in-memory `translationDataSample` snapshot only short-circuits hits.
2. On a miss, `deriveTranslation` may re-download the **entire `translations` tree** inline
   (`populateTranslationDataSnapshot(expiryThreshold: .seconds(120))`).
3. Platform translate (Google fast-path JSON API; web-view scrape fallbacks).
4. Optional Gemini enhancement (unbounded beyond URLSession defaults).
5. `addToHostedArchive` — an **awaited** RTDB write. This write is load-bearing: the message
   node stores only translation *references* (`Message.encoded`, key `translations`), and
   recipients resolve the actual text from the hosted archive.

Then one more round trip for the message commit. Audio additionally pays duplicate Storage
existence checks and defers its input-file upload until after transcription + translation + TTS
all complete. Media re-hashes the full file (read + SHA256) at least three times on the send
path and serializes the thumbnail upload behind the primary upload.

## Package layout & ordering

| Package | Repo | Changes |
|---|---|---|
| **Networking** | `grantbrooksgoodman/networking` | Phases N1–N4 |
| **Panther** (app) | `grantbrooksgoodman/panther` | Phases P1–P4 |
| **AppSubsystem** | `grantbrooksgoodman/app-subsystem` | **No changes** |
| **Translator** | `grantbrooksgoodman/translator` | **No changes** |

Implement in this order: **N1 → N2 → N3 → P1 → P2 → P3 → (optional) N4 → P4.**
P3 depends on N2. P1 and P2 have no cross-package dependencies and may be done any time.
Resolve package checkout locations locally; all dependencies are available on disk.

Behavioral constraints that apply everywhere:

- Dialog-string translation (`resolve(_:)`, `getTranslations` for `TranslatedLabelStrings`)
  must keep its current behavior, including immediate hosted-archive writes.
- Never archive idempotent language pairs to the hosted archive (existing rule in
  `HostedTranslationArchiver.addToHostedArchive`).
- The local (on-device) translation archiver must continue to receive new translations
  immediately in all paths.
- Recipients must never be able to observe a committed message whose translation references
  cannot be resolved from the hosted archive. Deferred archive writes must land **in the same
  atomic commit** as the message node, never after it.

---

## Networking package

### Phase N1 — Kill wasted reads on the archive-lookup path

Files: `Sources/Modules/Translation/Services/HostedTranslationArchiver.swift`,
`Sources/Modules/Translation/Services/HostedTranslationService.swift`

1. **Snapshot-authoritative misses.** In `findArchivedTranslation(id:languagePair:)`, when the
   in-memory `translationDataSample` is non-empty and unexpired, treat *absence* of the hash for
   the language pair as authoritative: skip the per-hash `database.getValues` round trip and go
   straight to the derivation attempt (which, after step 2, is in-memory only). Keep the network
   read as the fallback whenever the snapshot is empty or expired. Hits keep working as today.
2. **No full-tree download on the lookup path.** `deriveTranslation` currently calls
   `populateTranslationDataSnapshot(expiryThreshold: .seconds(120))` inline, which can download
   the entire `translations` node during a send. Change `deriveTranslation` to consult only the
   data already in memory. If the snapshot is empty/expired, fail derivation fast (the caller
   already treats `translationDerivationFailed` as a miss and proceeds to the platform
   translator).
3. **Background snapshot refresh.** Replace the single init-time populate (`Task.background`
   delayed 10 s) with a periodic background refresh so the snapshot stays fresh enough to be
   authoritative: re-populate on a timer whose interval is slightly below the sample expiry
   (e.g., refresh every 4 minutes with a 5-minute expiry), and trigger an immediate refresh when
   the app returns to foreground if expired. Keep the existing `isPopulating` reentrancy guard.
   The refresh must never be awaited by any translate/lookup caller.
4. Preserve the existing post-populate side effects (seeding `CoreDatabaseStore` and the local
   archiver from the snapshot) — they run detached at background priority already.

Success criteria: with a fresh snapshot, translating novel text performs **zero** RTDB reads
before hitting the platform translator; no code path downloads the full `translations` tree
inside a translate call.

### Phase N2 — Deferred hosted-archive writes (API for atomic merge)

Files: `Sources/Modules/Translation/Services/HostedTranslationArchiver.swift`,
`Sources/Modules/Translation/Services/HostedTranslationService.swift`,
`Sources/Modules/Translation/Protocols/HostedTranslationDelegate.swift`

1. **Expose the archive entry without writing it.** Factor the entry construction out of
   `addToHostedArchive` into something like:

   ```swift
   /// Environment-relative RTDB fan-out entry for archiving this
   /// translation, or nil for idempotent pairs / invalid values.
   /// Key example: "translations/en-es/<inputValueEncodedHash>"
   func hostedArchiveEntry(for translation: Translation) -> (key: String, value: Any)?
   ```

   It must apply the same validation and idempotent-pair exclusion as `addToHostedArchive`, and
   produce the identical path (`NetworkPath.translations.rawValue`/`languagePair.string`/
   `reference.type.key`) and value (`reference.type.value`). `addToHostedArchive` should be
   reimplemented on top of it so the two can never drift. Note the path is environment-relative,
   matching what `DatabaseDelegate.commit` / `updateChildValues` expect with default environment
   prepending — verify this against how Panther's `willWrite` builds its `updates` dictionary
   (same convention).
2. **Deferred-archiving translate variant.** Add an option to
   `translate(_:with:hud:enhance:)` (e.g., an `archival: ArchivalStrategy = .immediate`
   parameter with an `.deferred` case, threaded through to `postProcess`). Under `.deferred`:
   - Do **not** await `addToHostedArchive` anywhere in the call.
   - Still add the translation to the **local** archiver as today.
   - Return the pending hosted entry alongside the translation so the caller can merge it into
     its own atomic commit. A small result type is fine
     (`struct TranslationResult { let translation: Translation; let pendingArchiveEntry: (key: String, value: Any)? }`)
     or a separate `hostedArchiveEntry(for:)` call from the app — pick one mechanism and apply
     it consistently; the entry-builder + plain `Translation` return is the least invasive.
   - Cover every branch of `postProcess` that currently performs a hosted write
     (`.addToBothArchives` and `.addToHostedArchive` treatments), including the
     `prevalidateInput` branch that archives "no letters / already target language" results.
     Archive-hit branches (`.addToLocalArchive`) have no hosted write and are unaffected.
3. Update `HostedTranslationDelegate` so the new surface is reachable by app code. Default
   parameter values must keep all existing call sites source-compatible with unchanged behavior.

Success criteria: a caller can obtain a translation plus its would-be archive entry with zero
hosted-archive round trips inside the translate call; all existing callers compile unchanged
and still archive immediately.

### Phase N3 — Bound the Gemini enhancement call

File: `Sources/Modules/Gemini/Services/GeminiService.swift`

1. Set an explicit `timeoutInterval` on the enhancement `URLRequest` (default ~8 s; make it a
   constant, optionally configurable through `Networking.config` alongside the existing
   enhancement settings).
2. No other behavior change is needed: `HostedTranslationService.postProcess` already catches
   enhancement errors and falls back to the unenhanced translation, so a timeout degrades
   gracefully. Verify that the timeout error takes that existing catch path and is logged, not
   thrown to the send path.

### Phase N4 (optional) — Streaming file uploads

Files: `Sources/Modules/Storage/Protocols/StorageDelegate.swift`,
`Sources/Modules/Storage/Services/Storage.swift`,
`Sources/Modules/Storage/Services/CoreStorage.swift`

1. Add a file-URL upload API (e.g., `upload(fileAt: URL, metadata:...)`) implemented with
   Firebase Storage's `putFile` so large media streams from disk instead of being loaded fully
   into memory via `Data.fromURL` + `putData`.
2. Mirror the existing `upload(_ data:...)` semantics (environment prepending, timeout,
   `GuardedOperation` health instrumentation). Keep the `Data` overload; do not migrate
   Networking-internal callers.

---

## Panther (app)

### Phase P1 — Self-contained quick wins

No cross-package dependencies. Four independent changes:

1. **Prewarm the translation stack.**
   File: `Sources/Application.swift` (networking setup block, next to
   `networking.database.prewarm()` / `networking.storage.prewarm()` around line 127).
   Call `TranslationService.shared.prewarm()` (import `Translator`; it is `@MainActor`). This
   warms DNS/TLS for `translate.googleapis.com`, the web-view fallback pipeline, and the local
   archive index, so the first send after cold launch skips connection setup.

2. **Memoize `MediaFile` content hashing.**
   File: `Sources/Modules/Common/Models/MediaFile.swift`
   `hashFactors` (and everything built on it: `encodedHash`, `hash(into:)`) re-reads the whole
   file and SHA256s it on every access; the media send path does this at least three times
   (`MessageService.buildMessage` twice, `MediaMessageService.uploadMediaComponent` once).
   Add a process-wide memoization cache (e.g., a private `LockIsolated<[String: String]>` keyed
   by resolved local path + file size + modification date) so each unique file version is read
   and hashed once. Files at these paths are effectively immutable once written (they are
   content-addressed or freshly exported), so size+mtime keying is sufficient; a changed file
   produces a new key. Do not change the produced hash value or the `hashFactors` format —
   only avoid recomputation.

3. **Remove redundant Storage existence checks on the audio path.**
   Files: `Sources/Modules/Networking/Sources/Message/Services/AudioMessageService.swift`,
   `Sources/Modules/Session/Entity/Services/MessageSessionService.swift`
   - In `uploadAudioComponents.uploadOutput(for:)`: the caller (`sendAudioMessage`) already
     determined whether a pre-recorded output exists. The result is encoded by the placeholder
     convention: for a non-idempotent pair, `translated.url == original.url` means
     "pre-recorded output exists, nothing to upload." Use that instead of calling
     `preRecordedOutputExists` again: after the existing idempotent-pair guard, if
     `audioComponent.translated.url == audioComponent.original.url`, return without uploading
     (and without moving, which the existing `moveOutputFile` guard already handles). If the
     URLs differ, the component was just synthesized because the check said "absent" — upload
     unconditionally, no re-check. Storage uploads are idempotent (same content at the same
     content-addressed path), so the vanishing race window is harmless.
   - In `uploadAudioComponents.uploadInput()`: `preRecordedInputExists` can only be true when
     the message ID was reserved by an earlier attempt (outbox retry with `presetID`). Thread a
     flag through from `buildMessage` (which knows whether `presetID` was supplied) so the check
     is only performed for retries; fresh sends upload immediately. Signature suggestion:
     `uploadAudioComponents(_:for:isRetry:)`.

4. **Parallelize the media component upload.**
   File: `Sources/Modules/Networking/Sources/Message/Services/MediaMessageService.swift`
   Restructure `uploadMediaComponent(_:for:)`:
   - Run the two `itemExists` checks (primary file, thumbnail) **concurrently**.
   - Upload the primary file and the thumbnail **concurrently** (they are independent Storage
     objects), each skipped if its existence check returned true.
   - Perform the local `fileManager.move` steps after their respective uploads complete, exactly
     as today (primary move after primary upload; thumbnail move after thumbnail upload).
   - Preserve current semantics of the existing early-return nesting: primary exists +
     (no thumbnail needed or thumbnail exists) → move local files only, no uploads.
   Use the existing `forEachConcurrently` / task-group idioms found elsewhere in this file's
   module for consistency.

### Phase P2 — Audio: upload the input file at send-press

Files: `Sources/Modules/Session/Entity/Services/MessageSessionService.swift`,
`Sources/Modules/Networking/Sources/Message/Services/MessageService.swift`,
`Sources/Modules/Networking/Sources/Message/Services/AudioMessageService.swift`

The input recording is the largest network payload of an audio send, and it depends only on the
recording itself and the message ID — yet today it uploads after transcription, translation,
and TTS have all finished. Hide it behind that compute:

1. In `sendAudioMessage(_:presetID:toUsers:inConversation:)`, resolve the message ID **first**:
   `presetID ?? networking.database.generateKey(for: NetworkPath.messages.rawValue)`
   (key generation is local). Keep the existing thrown Exception behavior if generation fails.
2. Immediately start a structured concurrent task that uploads the input file under that ID.
   Extract the upload core from `uploadAudioComponents.uploadInput()` into a reusable
   `AudioMessageService` method, e.g.
   `uploadInputAudioComponent(_ inputFile: AudioFile, messageID: String, isRetry: Bool)`, which:
   - performs the `preRecordedInputExists` check only when `isRetry` is true (Phase P1.3),
   - uploads the file data,
   - does **not** move the local file (see step 4).
3. Pass the resolved ID as `presetID` into `buildMessage`, and pass the in-flight upload task
   (or an equivalent handle) down so `uploadAudioComponents` **awaits it instead of re-running
   the input upload**. Propagate an upload failure exactly where `uploadInput()` would have
   thrown today, so error handling and the outbox-retry path are unchanged.
4. Keep the local file move (input file → documents cache path named by message ID) where it
   happens today — after the upload completes, inside the buildMessage/upload phase — because
   transcription reads the file at its original URL at the start of the send. Concurrent *reads*
   (transcription + upload) of the same file are safe; the *move* must remain sequenced after
   both.
5. If the send fails after the upload succeeded, no cleanup is required: retries reuse the
   reserved ID (`OutboxEntry.reservedRemoteID`) and the `isRetry` existence check turns the
   re-upload into a no-op; orphaned inputs are already handled by the existing deletion paths.

Optional stretch within this phase: start each language's *output* upload as soon as its TTS
synthesis finishes rather than after the whole translation task group joins (today the slowest
language gates every upload). Only attempt this if it can be done without breaking the
delivery-progress accounting in `sendAudioMessage`; otherwise leave for P4.

### Phase P3 — Merge hosted-archive writes into the atomic message commit

Depends on Networking Phase N2.
Files: `Sources/Modules/Session/Entity/Services/MessageSessionService.swift`,
`Sources/Modules/Networking/Sources/Conversation/RemotelyUpdatable/Conversation+RemotelyUpdatable.swift`,
`Sources/Modules/Networking/Sources/Conversation/Services/ConversationService.swift`,
plus a small new registry in `Sources/Modules/Session/State/Services/`.

Goal: the RTDB write that archives each new translation lands in the **same**
`database.commit` as the message node, removing one awaited round trip per language and making
archive + message atomic.

1. Switch the three message-send translate call sites in `MessageSessionService`
   (`sendAudioMessage`'s task group, `sendTextMessage`'s `parallelMap`, and the dev-mode
   pre-translate can stay immediate) to the deferred-archival variant from N2, collecting each
   translation's pending archive entry.
2. Add a `PendingTranslationArchive` registry (mirror the shape of the existing
   `SelfWriteRegistry`: a `LockIsolated` static store). Key entries by translation reference
   hosting key (`translation.reference.hostingKey`) with the `(key, value)` fan-out entry as
   payload. `MessageSessionService` records entries there before calling
   `createMessageAndAddToConversation`.
3. In `Conversation.willWrite(_:forKey:updating:)`, when building the fan-out `updates` for new
   messages, drain the registry entries matching each new message's `translationReferences` and
   merge them into `updates` before `database.commit`. Do the same in
   `ConversationService.createConversation` for the first-message path. Drain (remove) entries
   only once they have been merged into a commit payload; on commit failure they will be
   re-recorded by the retry's translate pass (local-archive hits make that free), so no
   replay machinery is needed — but make the registry idempotent (re-recording the same key
   overwrites).
4. Verify path conventions match: the entries from N2 are environment-relative, exactly like the
   other keys `willWrite` puts into `updates` (`messages/...`, `users/...`), and
   `database.commit` applies environment prepending uniformly.
5. Ordering guarantee to preserve: a message node must never be committed without its archive
   entries in the same payload. Audio messages rely on this identically to text (recipients
   resolve `Translation(from: reference)` from the archive when decoding).

Success criteria: sending a text message with N recipient languages performs exactly one RTDB
write round trip (the commit), with `translations/...` keys present in the same payload;
recipients can decode the message immediately after the commit.

### Phase P4 (optional) — Adopt streaming uploads and finish audio pipelining

Depends on Networking Phase N4 (for the upload part).

1. Switch the large-payload upload call sites to the new file-URL API:
   `AudioMessageService.upload(audioFile:to:)` and both uploads in
   `MediaMessageService.uploadMediaComponent`. Leave small payloads as-is.
2. If not already done in P2, restructure `sendAudioMessage` so each language's output upload
   begins when that language's TTS completes (per-language pipeline), keeping
   delivery-progress increments consistent.

---

## Explicitly out of scope

- **Live transcription during recording** (`SFSpeechAudioBufferRecognitionRequest`): larger
  architectural change; not part of this plan.
- Any change to the atomic fan-out structure, `SelfWriteRegistry` semantics, notification
  delivery, read receipts, or the outbox retry state machine beyond what is listed.
- Writing tests or adding test targets — do not add any.

## Verification

- After each Networking phase, build the Networking package, then build Panther against the
  updated dependency. After each Panther phase, build the app target.
- Manual sanity checks per phase (simulator, two accounts with different language codes where
  translation behavior matters):
  - N1/N2/P3: send novel text; confirm exactly one RTDB commit carries both the message and its
    `translations/...` entries, the recipient renders the text, and repeated sends of the same
    text hit the local archive with no hosted reads.
  - N3: with enhancement enabled and network throttled, confirm a slow Gemini call falls back
    to the unenhanced translation within the timeout instead of stalling delivery.
  - P1: send an image and a video (thumbnail present); confirm both objects land in Storage and
    local files end up at the same cached paths as before. Send an audio message to a language
    with a pre-recorded output and to one without; confirm no duplicate existence checks and
    unchanged results.
  - P2: send a long audio message; confirm the input object appears in Storage while
    transcription/translation is still running, the local cached copy exists at the
    ID-named path afterward, and an outbox retry of a failed send does not double-upload.
- Watch the existing logger domains (`hostedTranslation`, `messageOutbox`, `Networking.database`)
  for regressions; they already trace each leg of the send path.
