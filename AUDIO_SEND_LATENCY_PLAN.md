# Audio Message Send Latency — Implementation Plan

## Objective

Reduce the time between the user finishing an audio recording and the message being sent. The current pipeline is almost entirely serial and does redundant work. This plan is four phases, ordered so each lands independently. Implement them in order; each phase leaves the app fully functional.

## Current pipeline (for orientation)

`InputBarActionHandlerService.didPressRecordButton(.stopRecording)` (`Sources/Modules/Content/User/Services/ChatPageView/Sources/InputBar/Sources/InputBarActionHandlerService.swift:109`) stops the `AVAudioRecorder` and calls `MessageDeliveryService.sendAudioMessage` (`Sources/Modules/Content/User/Services/MessageDeliveryService.swift:91`), which calls `MessageSessionService.sendAudioMessage` (`Sources/Modules/Session/Entity/Services/MessageSessionService.swift:37`). That runs, in series:

1. **Transcription** of the finished file (`TranscriptionService.transcribeAudioFile`, whole-file `SFSpeechURLRecognitionRequest`). Nothing starts until this completes; on the draft/new-conversation path even the optimistic message bubble waits on it.
2. **Per recipient language** (a task group, nominally parallel): translate → `preRecordedOutputExists` storage round trip → `TextToSpeechService.readToFile`, which synthesizes speech to a PCM float32 `.caf`, then re-encodes it to `.m4a` through a full `AVAssetExportSession` pass. All TTS synthesis is globally serialized by the `TextToSpeechWriteGate` actor, defeating the task group's parallelism.
3. **Upload** (`AudioMessageService.uploadAudioComponents`): a sequential loop with a `preRecordedInputExists` round trip and a *second* `preRecordedOutputExists` round trip per component.
4. Message build + conversation write.

The phases below: (1) remove the double encode, (2) remove the TTS serialization, (3) parallelize the uploads, (4) transcribe while recording so step 1 is ~free.

---

## Phase 1 — Encode M4A directly during TTS synthesis (remove the CAF → M4A export pass)

**File:** `Sources/Modules/Common/Services/Sources/Audio/TextToSpeechService.swift`

`AVAudioFile(forWriting:settings:commonFormat:interleaved:)` encodes on the fly when the settings describe a compressed format: you keep writing the same PCM buffers, and the file comes out as AAC in an `.m4a` container. This makes the intermediate `.caf` and the entire `AVAssetExportSession` pass (plus its `asset.load(.metadata)` call and 10-second timeout) unnecessary.

Changes:

1. In `getAudioFile(from:languageCode:)`, when creating the output `AVAudioFile` from the first buffer, target the **final `.m4a` path** (`"\(languageCode)-\(FileNames.outputM4A)"`) with AAC settings instead of the `.caf` path with the buffer's raw settings:

   ```swift
   output = try AVAudioFile(
       forWriting: filePath, // now the .m4a URL
       settings: [
           AVFormatIDKey: kAudioFormatMPEG4AAC,
           AVSampleRateKey: pcmBuffer.format.sampleRate,
           AVNumberOfChannelsKey: pcmBuffer.format.channelCount,
           AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
       ],
       commonFormat: .pcmFormatFloat32,
       interleaved: false
   )
   ```

   The sample rate and channel count **must** come from `pcmBuffer.format` — `AVAudioFile.write(from:)` does not sample-rate convert, and a mismatch throws. The existing `mustIncludeAudioFileSettings: true` voice constraint stays as-is.

2. Before creating the file, remove any pre-existing file at the output URL (the same remove-if-exists logic currently in `convertToM4A` at lines 125–136 — move it here).

3. `readToFile` now returns the URL from `getAudioFile` directly. Delete `convertToM4A` entirely, along with the `extension AVAssetExportSession: @retroactive @unchecked Sendable` at the bottom of the file and the now-unused `AVFoundation` export imports if nothing else needs them.

4. Keep the existing 10-second `Timeout` around synthesis in `getAudioFile` — that's still wanted.

5. Delete `AudioService.FileNames.outputCAF` (`Sources/Modules/Common/Services/Sources/Audio/AudioService.swift:21`) and the CAF-cleanup block in `AudioMessageService.uploadAudioComponents` (`Sources/Modules/Networking/Sources/Message/Services/AudioMessageService.swift:118–129` — the `fileManager.removeItem` of the `.caf` sibling inside `moveOutputFile`). Then grep the codebase for remaining `.caf` / `outputCAF` / `AudioFileExtension.caf` references and clean up any that existed solely to support this intermediate file (do not touch unrelated CAF support in playback or file-type enums that other features use).

**Behavioral invariant:** the output file name and location (`documents/<languageCode>-output.m4a`) must remain exactly what `preRecordedOutputExists` (`AudioMessageService.swift:160`) and the `moveOutputFile` logic expect — this phase changes *how* the file is produced, not where it lands. (Phase 2 changes the directory; see below.)

---

## Phase 2 — Parallelize TTS across recipient languages (remove the global write gate)

**File:** `Sources/Modules/Common/Services/Sources/Audio/TextToSpeechService.swift`

`TextToSpeechWriteGate` (line 325) exists because all calls share the single `@Dependency(\.avSpeechSynthesizer)` instance, which cannot service concurrent `write(_:toBufferCallback:)` calls. A group conversation with N recipient languages therefore pays N× TTS sequentially even though `MessageSessionService.sendAudioMessage`'s task group fans out per language.

Changes:

1. In `getAudioFile`, create a **fresh local `AVSpeechSynthesizer`** per call instead of using the shared dependency. Hold a strong reference for the duration of the write (e.g. capture it in the continuation closure or use `withExtendedLifetime`) — if the synthesizer deallocates mid-write, synthesis silently stops. Do **not** remove the `\.avSpeechSynthesizer` dependency from the DI container; other call sites (e.g. `InputBarActionHandlerService`'s `stopSpeaking` calls) still use the shared instance for playback.

2. Delete the `TextToSpeechWriteGate` actor and the `.run { ... }` wrapper in `getAudioFile`.

3. **Filename collisions:** the gate also incidentally prevented two concurrent syntheses of the same language from clobbering each other's `<languageCode>-output.m4a` (possible when an outbox retry overlaps a fresh send — never within one message, since `uniqueLanguageCodes` are unique). Synthesize into a **unique per-call subdirectory**: `documents/tts-<UUID>/<languageCode>-output.m4a`. The file *name* must stay `<languageCode>-output.m4a` because `AudioFile.name` (derived from the URL) flows into `uploadAudioComponents`' `moveOutputFile`, which moves the file by its full source URL to `documents/<translatedDirectoryPath>/<name>.m4a` — so a unique parent directory is transparent to all downstream code. After `moveOutputFile` relocates the file, the empty `tts-<UUID>` directory should be removed; add that cleanup where the CAF cleanup used to be in `uploadAudioComponents`.

4. Verify with a grep that nothing else assumes the synthesized file sits directly in the documents root before `moveOutputFile` runs (check `LocalAudioFilePath`, `AudioFile+UserContentExtensions`, and `AppConstants+AudioFile`).

---

## Phase 3 — Parallelize the upload path

**File:** `Sources/Modules/Networking/Sources/Message/Services/AudioMessageService.swift`, function `uploadAudioComponents` (line 69 — note its existing `// TODO: Can be parallelized with some rethinking.`)

Today the loop runs component-by-component. Within one message, every component shares the same `original` input file (the `lastUploadedInput` guard papers over this), so the input work belongs outside the loop, and the per-component output work is independent.

Restructure to:

1. **Input, once, up front (concurrently with outputs):** rename/wrap the input as `message.id` (the existing `uploadInput` logic), check `preRecordedInputExists` (keep this check — it saves a re-upload when the outbox retry path re-sends with the same preset message ID), upload if absent, then move the local input file to `documents/<audioMessageInputs>/<message.id>.<ext>` (the existing `didMoveInputFile` block). These three steps stay sequential relative to each other. Delete `lastUploadedInput` and `didMoveInputFile`.

2. **Outputs, in parallel:** for all components where `!audioComponent.translation.languagePair.isIdempotent`, run concurrently (task group or the codebase's existing `forEachConcurrently` / `parallelMap` helpers — see `Sources/Modules/Networking/Sources/Message/Services/MessageService.swift:229` and `:326` for precedent): `preRecordedOutputExists` check → upload if absent → `moveOutputFile`. Keep per-component ordering (check → upload → move) but let components overlap each other and the input work (e.g. `async let` for the input alongside the group).

3. **Guard the placeholder move:** for components where the pre-recorded output already existed, `MessageSessionService` sets `translated` to the *input* file as a placeholder (`MessageSessionService.swift:108–115`). Today `moveOutputFile` tries to move that placeholder URL and logs a spurious error once the input has been moved. Skip `moveOutputFile` when `audioComponent.translated.url == audioComponent.original.url`.

4. Error semantics: the function currently throws on the first upload failure. Preserve that — cancel the group / fail fast on the first thrown `Exception` (this is what `failFast`/`returnOnFailure` patterns elsewhere in `MessageService` do).

Also remove the stale second `preRecordedOutputExists` mention from `MessageSessionService` only if you find one *outside* the task group — the check inside the task group (`MessageSessionService.swift:105`) stays; it's what decides whether to synthesize at all. The redundancy being removed here is only the duplicated *network round trips* now overlapping, plus the TODO.

---

## Phase 4 — Transcribe while recording (streaming recognition)

This is the largest perceived win for long recordings: today, whole-file recognition starts only after the user taps stop, and *everything* — including the optimistic bubble on the draft path — waits for it. Goal: the transcript is (nearly) final the moment recording stops.

**Design:** feed live mic buffers to a `SFSpeechAudioBufferRecognitionRequest` during recording. `AVAudioRecorder` exposes no buffers, so `RecordingService` moves to `AVAudioEngine` with an input tap that both writes the `.m4a` and feeds recognition. The file-based `transcribeAudioFile` stays untouched as the fallback (the outbox retry path in `Sources/Modules/Session/State/Services/MessageOutboxService+Retry.swift` re-sends from a stored file with no live session, and the live path can fail).

### 4a. `TranscriptionService` — add a live session

**File:** `Sources/Modules/Common/Services/Sources/Audio/TranscriptionService.swift`

Add a `LiveTranscriptionSession` (final class) alongside the existing API:

- `TranscriptionService.startLiveSession(languageCode:) -> LiveTranscriptionSession?` — returns `nil` (never throws) when transcribe permission isn't `.granted`, the language is unsupported (reuse `isTranscriptionSupported`), or `SFSpeechRecognizer(locale:)` fails. `nil` simply means "fall back to file transcription later."
- Internally: `SFSpeechAudioBufferRecognitionRequest` with `addsPunctuation = true`, `shouldReportPartialResults = true` (partials keep the recognizer warm; only the final result is consumed), and a recognition task whose handler stores the latest transcription and completes a continuation on `result.isFinal` or error.
- `append(_ buffer: AVAudioPCMBuffer)` — forwards to `request.append(buffer)`. Must be safe to call from the audio tap's realtime-adjacent thread (no locks around anything slow; `SFSpeechAudioBufferRecognitionRequest.append` is designed for this).
- `finish() async -> String?` — calls `request.endAudio()`, awaits the final result with a short timeout (the codebase's `Timeout` helper, ~5 s — recognition of already-streamed audio finalizes fast), returns `nil` on error/timeout/empty string. Never throws.
- `cancel()` — cancels the recognition task; used when recording is cancelled or interrupted.
- Guard single completion the same way the file-based path does (the `didComplete`/`canComplete` pattern).
- Note: server-based recognition caps buffer requests at ~1 minute of audio. Do not set `requiresOnDeviceRecognition`; if the session errors for any reason (including that cap), `finish()` returns `nil` and the caller falls back to `transcribeAudioFile`, which is the status quo.

### 4b. `RecordingService` — `AVAudioEngine` instead of `AVAudioRecorder`

**File:** `Sources/Modules/Common/Services/Sources/Audio/RecordingService.swift`

- `startRecording(bufferSink: ((AVAudioPCMBuffer) -> Void)? = nil)`:
  - Keep `audioService.activateAudioSession()` and the interruption observation exactly as they are.
  - Create an `AVAudioEngine`; install a tap on `inputNode` (bus 0) using `inputNode.outputFormat(forBus: 0)`.
  - Create the output `AVAudioFile` at the same path (`documents/input.m4a`, `FileNames.inputM4A`) with AAC settings whose **sample rate and channel count mirror the tap format** (`AVFormatIDKey: kAudioFormatMPEG4AAC`, `AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue`). As in Phase 1, `AVAudioFile.write(from:)` requires the processing format to match the buffers — the fixed 12 kHz mono of the old recorder settings cannot be kept without an `AVAudioConverter`; use the hardware rate (the size increase of an AAC voice clip is acceptable).
  - In the tap block: write the buffer to the file (log-don't-crash on error, mirroring `audioRecorderEncodeErrorDidOccur`'s stop-and-log behavior), then call `bufferSink?(buffer)`.
  - `engine.prepare()` + `engine.start()`.
- `stopRecording() -> URL`: remove the tap, stop the engine, release the `AVAudioFile` reference (releasing finalizes the file — do this before returning), return the URL. Preserve the existing "no recorder to stop" `Exception` semantics when called while not recording (same error identity that `InputBarActionHandlerService` matches with `.noAudioRecorderToStop`).
- `cancelRecording()`: unchanged shape — stop, then delete the file.
- `isRecording` / `willStartRecording` / `isInOrWillTransitionToRecordingState` (see `RecordingService+UserContentExtensions.swift`): keep the same observable semantics, now backed by `engine.isRunning`.
- Delete the `AVAudioRecorderDelegate` conformance; the interruption-notification path already covers mid-recording teardown (its handler calls `stopRecording()` — also `cancel()` the live session there if you route it through the service; with the sink-closure design, interruption handling for the session lives in the Content layer, see 4c, so `stopRecording` alone is fine).

### 4c. Wiring — start/finish the session around recording

**File:** `Sources/Modules/Content/User/Services/ChatPageView/Sources/InputBar/Sources/InputBarActionHandlerService.swift`

- Add `@Dependency(\.clientSession)` (already used from this module in `MessageDeliveryService`) to read `clientSession.entity.user.currentUser?.languageCode` — the same language the transcription currently uses.
- Hold `private var liveTranscriptionSession: LiveTranscriptionSession?`.
- `.startRecording`: create the session via `services.audio.transcription.startLiveSession(languageCode:)` *before* `startRecording`, and pass `liveTranscriptionSession?.append` (wrapped) as the `bufferSink`. A `nil` session just means no sink.
- `.stopRecording`: after `stopRecording()` returns the URL, `let transcript = await liveTranscriptionSession?.finish()`, nil out the property, and pass the transcript along: `try await messageDeliveryService.sendAudioMessage(inputFile, transcription: transcript)`.
- `.cancelRecording`: `liveTranscriptionSession?.cancel()`, nil it out.

### 4d. Plumb the transcript through the send path

- `MessageDeliveryService.sendAudioMessage(_:transcription:)` (`Sources/Modules/Content/User/Services/MessageDeliveryService.swift:91`): add `transcription: String? = nil`, forward it.
- `MessageSessionService.sendAudioMessage` (`Sources/Modules/Session/Entity/Services/MessageSessionService.swift:37`): add `transcription: String? = nil`. Use it when non-nil and non-blank; otherwise call `services.audio.transcription.transcribeAudioFile` exactly as today. Everything downstream — the `audioMessageTranscriptionSucceeded` notification post, translation fan-out, delivery-progress increments — is unchanged and now fires immediately when a live transcript was supplied.
- The outbox retry call site (`MessageOutboxService+Retry.swift:130`) needs no change thanks to the defaulted parameter; it naturally takes the file-based fallback.

---

## Ordering and verification

- Implement in phase order. Phase 2 assumes Phase 1's direct-M4A write (the unique-subdirectory decision replaces the CAF cleanup). Phases 3 and 4 are independent of each other but both build cleanly on 1–2.
- After each phase, build the app and exercise the audio-send flow mentally against these invariants:
  - Storage layout is unchanged: inputs at `<audioMessageInputs>/<messageID>.m4a`, outputs at `<audioTranslations>/<hostingKey>/<languageCode>-output.m4a`.
  - Local post-send layout is unchanged: input and outputs end up under `documents/` at the paths `MessageService.buildMessage` rewrites into the message (`MessageService.swift:108–125`), which is what `cachedAudioMessageReference` reads back for playback.
  - The pre-recorded-output shortcut, the idempotent-language-pair skip, and the outbox retry path all still work.
- Do not add tests or a test target.
