//
//  TextToSpeechService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length

/* Native */
import AVFAudio
import Foundation

/* Proprietary */
import AppSubsystem

/// Use ``TextToSpeechService`` to synthesize speech from text.
///
/// The service writes synthesized speech to M4A files on disk and reports which languages
/// support synthesis. Voice and language support lookups are cached in memory.
struct TextToSpeechService {
    // MARK: - Type Aliases

    private typealias DirectoryNames = AudioService.DirectoryNames
    private typealias FileNames = AudioService.FileNames

    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Read to File

    /// Synthesizes the given text to an audio file.
    ///
    /// Synthesis uses the highest quality voice available for the given language. Requests are
    /// throttled; concurrent calls may suspend until earlier requests complete.
    ///
    /// - Parameters:
    ///   - text: The text to synthesize.
    ///   - languageCode: The language code of the voice with which to synthesize the text.
    ///
    /// - Returns: The URL of the synthesized M4A file, located in a uniquely named directory
    ///   within the app's Documents directory.
    ///
    /// - Throws: An `Exception` if the speech voice inventory does not become available within
    ///   five seconds, if text to speech is not supported for the given language code, if
    ///   synthesis fails, or if it does not complete within 10 seconds.
    func readToFile(
        text: String,
        languageCode: String
    ) async throws(Exception) -> URL {
        try await TextToSpeechVoiceInventory.shared.awaitLoaded()

        guard isTextToSpeechSupported(for: languageCode) else {
            throw Exception(
                "Text to speech is not supported for the specified language code.",
                userInfo: ["LanguageCode": languageCode],
                metadata: .init(sender: self)
            )
        }

        return try await getAudioFile(
            from: text,
            languageCode: languageCode
        )
    }

    // MARK: - Highest Quality Voice

    /// Returns the highest quality voice available for the given language code.
    ///
    /// The lookup prefers enhanced- and premium-quality voices whose language matches the given
    /// code, falling back to the system's default voice for the language. Results are cached in
    /// memory per language code.
    ///
    /// - Parameters:
    ///   - languageCode: The language code for which to find a voice.
    ///   - mustIncludeAudioFileSettings: A Boolean value that indicates whether matching voices
    ///     must also provide audio file settings, which are required to write synthesized speech
    ///     to a file. The default is `false`.
    ///
    /// - Returns: The highest quality voice for the language code; otherwise, `nil` if no voice
    ///   is available.
    ///
    /// - Note: Cached results are keyed by language code only; the `mustIncludeAudioFileSettings`
    ///   constraint applies only when the language code is not already cached.
    ///
    /// - Note: The lookup consults the voice inventory without blocking. While the inventory is
    ///   still loading, this method starts the load and returns `nil` without caching a result.
    func highestQualityVoice(
        _ languageCode: String,
        mustIncludeAudioFileSettings: Bool = false
    ) -> AVSpeechSynthesisVoice? {
        func satisfiesConstraints(_ voice: AVSpeechSynthesisVoice) -> Bool {
            if mustIncludeAudioFileSettings {
                guard voice.quality == .enhanced || voice.quality == .premium,
                      !voice.audioFileSettings.isEmpty else { return false }
            } else {
                guard voice.quality == .enhanced || voice.quality == .premium else { return false }
            }

            return true
        }

        if let cachedValue = _TextToSpeechServiceCache.cachedVoicesForLanguageCodes?[languageCode] {
            return cachedValue
        }

        guard let voices = TextToSpeechVoiceInventory.shared.loadedVoices else {
            TextToSpeechVoiceInventory.shared.load()
            return nil
        }

        if let voiceForLanguageCode = voices
            .filter({ $0.language.lowercased().hasPrefix(languageCode.lowercased()) })
            .first(where: { satisfiesConstraints($0) }) ?? .init(language: languageCode) {
            var cachedVoicesForLanguageCodes = _TextToSpeechServiceCache.cachedVoicesForLanguageCodes ?? [:]
            cachedVoicesForLanguageCodes[languageCode] = voiceForLanguageCode
            _TextToSpeechServiceCache.cachedVoicesForLanguageCodes = cachedVoicesForLanguageCodes

            return voiceForLanguageCode
        }

        return nil
    }

    // MARK: - Capabilities

    /// Returns a Boolean value that indicates whether text to speech is supported for the given
    /// language code.
    ///
    /// Support is determined by whether any installed voice matches the given code. Results are
    /// cached in memory per language code.
    ///
    /// - Parameter languageCode: The language code for which to check support.
    ///
    /// - Returns: `true` if text to speech is supported for the given language code; otherwise,
    ///   `false`.
    ///
    /// - Note: The check consults the voice inventory without blocking. While the inventory is
    ///   still loading, this method starts the load and returns `false` without caching a result.
    func isTextToSpeechSupported(for languageCode: String) -> Bool {
        if let cachedValue = _TextToSpeechServiceCache.cachedTextToSpeechSupportForLanguageCodes?[languageCode] {
            return cachedValue
        }

        guard let voices = TextToSpeechVoiceInventory.shared.loadedVoices else {
            TextToSpeechVoiceInventory.shared.load()
            return false
        }

        let isTextToSpeechSupported = voices.contains(where: {
            $0.language.lowercased().hasPrefix(languageCode.lowercased())
        })

        // swiftlint:disable:next identifier_name
        var cachedTextToSpeechSupportForLanguageCodes = _TextToSpeechServiceCache.cachedTextToSpeechSupportForLanguageCodes ?? [:]
        cachedTextToSpeechSupportForLanguageCodes[languageCode] = isTextToSpeechSupported
        _TextToSpeechServiceCache.cachedTextToSpeechSupportForLanguageCodes = cachedTextToSpeechSupportForLanguageCodes
        return isTextToSpeechSupported
    }

    // MARK: - Prewarm

    /// Begins loading the voice inventory in the background if it has not already started.
    ///
    /// Call this once at app startup so the first synthesis or support query need not wait on the
    /// speech daemon. The inventory loads at most once; subsequent calls have no effect.
    func prewarmVoiceInventory() {
        TextToSpeechVoiceInventory.shared.load()
    }

    // MARK: - Degraded Launch

    /// Degrades synthesis to serial traffic for the cooldown window.
    ///
    /// Call this at app startup when the previous process is known to have terminated mid-synthesis,
    /// so the first synthesis after an unclean launch does not overwhelm a potentially wedged speech
    /// daemon. The throttle self-heals back to full width once the cooldown window elapses.
    func degradeSynthesisAfterUncleanLaunch() async {
        await SynthesisThrottle.shared.recordFailure()
    }

    // MARK: - Auxiliary

    private func getAudioFile(
        from text: String,
        languageCode: String
    ) async throws(Exception) -> URL {
        await SynthesisThrottle.shared.acquire()

        do {
            // A cancelled sibling in the send task group must not
            // load the daemon; bail before any synthesizer is created.
            guard !Task.isCancelled else {
                throw Exception(
                    "Synthesis cancelled.",
                    isReportable: false,
                    metadata: .init(sender: self)
                )
            }

            let voice = highestQualityVoice(
                languageCode,
                mustIncludeAudioFileSettings: true
            )

            guard let voice,
                  !voice.audioFileSettings.isEmpty else {
                throw Exception(
                    "The selected voice cannot render audio to a file.",
                    userInfo: ["LanguageCode": languageCode],
                    metadata: .init(sender: self)
                )
            }

            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice

            let outputDirectoryURL = fileManager.documentsDirectoryURL.appending(
                path: "\(DirectoryNames.textToSpeechOutputPrefix)\(UUID().uuidString)"
            )

            try fileManager.createDirectory(
                at: outputDirectoryURL,
                withIntermediateDirectories: true
            )

            let outputFileURL = try await TextToSpeechSynthesisSession(
                outputDirectoryURL: outputDirectoryURL,
                outputFileURL: outputDirectoryURL.appending(path: "\(languageCode)-\(FileNames.outputM4A)"),
                utterance: utterance
            ).synthesize()

            await SynthesisThrottle.shared.release()
            return outputFileURL
        } catch {
            let exception = error as? Exception ?? .init(
                error,
                metadata: .init(sender: self)
            )

            // Any genuine synthesis failure signals daemon distress
            // and degrades the throttle; cancellation is not distress,
            // so it does not.
            if !Task.isCancelled {
                await SynthesisThrottle.shared.recordFailure()
            }

            await SynthesisThrottle.shared.release()
            throw exception
        }
    }
}

private final class TextToSpeechSynthesisSession: @unchecked Sendable {
    // MARK: - Types

    private struct State {
        var avSpeechSynthesizer: AVSpeechSynthesizer?
        var continuation: CheckedContinuation<URL, Error>?
        var gracePeriodTimeout: Timeout?
        var output: AVAudioFile?
        var preservesOutputDirectory = false
        var timeout: Timeout?
    }

    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Properties

    private static let activeWriteSessionCount = LockIsolated(0)
    private static let retainedSessions = LockIsolated([UUID: TextToSpeechSynthesisSession]())
    private static let writeQueue = DispatchQueue(
        label: "us.neotechnica.panther.tts-write",
        qos: .userInitiated
    )

    private let id = UUID()
    private let outputDirectoryURL: URL
    private let outputFileURL: URL
    private let utterance: AVSpeechUtterance

    @LockIsolated private var state = State()

    // MARK: - Init

    init(
        outputDirectoryURL: URL,
        outputFileURL: URL,
        utterance: AVSpeechUtterance
    ) {
        self.outputDirectoryURL = outputDirectoryURL
        self.outputFileURL = outputFileURL
        self.utterance = utterance
    }

    // MARK: - Synthesize

    func synthesize() async throws -> URL {
        Self.beginWriteSession()
        return try await withCheckedThrowingContinuation { continuation in
            $state.withValue { state in
                state.continuation = continuation
                state.timeout = Timeout(after: .seconds(10)) { [weak self] in
                    guard let self else { return }
                    complete(throwing: .timedOut(
                        metadata: .init(sender: self)
                    ))
                }
            }

            // Initiating the write on a dedicated queue keeps a stalled TTS daemon
            // from wedging a cooperative-pool thread.
            Self.writeQueue.async {
                let avSpeechSynthesizer = AVSpeechSynthesizer()
                self.$state.withValue { $0.avSpeechSynthesizer = avSpeechSynthesizer }

                avSpeechSynthesizer.write(self.utterance) { [weak self] buffer in
                    self?.handle(buffer)
                }
            }
        }
    }

    // MARK: - Auxiliary

    private static func beginWriteSession() {
        // The flag persists across the write and the synthesizer's
        // grace-period retention; if the process dies within that window
        // the daemon may be wedged, and the next launch degrades.
        @Persistent(.ttsSynthesisInFlight) var synthesisInFlight: Bool?
        activeWriteSessionCount.projectedValue.withValue { $0 += 1 }
        synthesisInFlight = true
    }

    private static func endWriteSession() {
        @Persistent(.ttsSynthesisInFlight) var synthesisInFlight: Bool?
        let remaining = activeWriteSessionCount
            .projectedValue
            .withValue { count -> Int in
                count = max(0, count - 1)
                return count
            }

        synthesisInFlight = remaining > 0 ? true : nil
    }

    private func complete(throwing exception: Exception) {
        let continuation: CheckedContinuation<URL, Error>? = $state.withValue { state in
            state.timeout?.cancel()
            state.timeout = nil

            defer { state.continuation = nil }
            return state.continuation
        }

        guard let continuation else { return }
        retainForGracePeriod(preservingOutputDirectory: false)

        Self.writeQueue.async {
            self.state.avSpeechSynthesizer?.stopSpeakingIfNeeded()
        }

        continuation.resume(throwing: exception)
    }

    private func handle(_ buffer: AVAudioBuffer) {
        guard let pcmBuffer = buffer as? AVAudioPCMBuffer else {
            return complete(throwing: .init(
                "Failed to typecast buffer to AVAudioPCMBuffer.",
                metadata: .init(sender: self)
            ))
        }

        guard pcmBuffer.frameLength != 0 else { return handleTerminalBuffer() }

        let writeError: Error? = $state.withValue { state in
            guard state.continuation != nil else { return nil }

            do {
                if state.output == nil {
                    state.output = try AVAudioFile(
                        forWriting: outputFileURL,
                        settings: [
                            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                            AVFormatIDKey: kAudioFormatMPEG4AAC,
                            AVNumberOfChannelsKey: pcmBuffer.format.channelCount,
                            AVSampleRateKey: pcmBuffer.format.sampleRate,
                        ],
                        commonFormat: .pcmFormatFloat32,
                        interleaved: false
                    )
                }

                try state.output?.write(from: pcmBuffer)
                return nil
            } catch {
                return error
            }
        }

        guard let writeError else { return }
        complete(throwing: .init(
            writeError,
            metadata: .init(sender: self)
        ))
    }

    private func handleTerminalBuffer() {
        let (continuation, didGenerateOutput): (CheckedContinuation<URL, Error>?, Bool) = $state.withValue { state in
            state.timeout?.cancel()
            state.timeout = nil

            defer {
                // Releasing the file reference finalizes the M4A container; the URL must not escape before then.
                state.continuation = nil
                state.output = nil
            }

            return (state.continuation, state.output != nil)
        }

        guard let continuation else { return releaseFromRetentionRegistry() }
        guard didGenerateOutput else {
            try? fileManager.removeItem(at: outputDirectoryURL)
            retainForGracePeriod(preservingOutputDirectory: false)
            return continuation.resume(throwing: Exception(
                "Failed to generate output.",
                metadata: .init(sender: self)
            ))
        }

        retainForGracePeriod(preservingOutputDirectory: true)
        continuation.resume(returning: outputFileURL)
    }

    private func releaseFromRetentionRegistry() {
        guard Self.retainedSessions.projectedValue.withValue({
            $0.removeValue(forKey: id)
        }) != nil else { return }

        Self.endWriteSession()
        let preservesOutputDirectory: Bool = $state.withValue { state in
            state.gracePeriodTimeout?.cancel()
            state.gracePeriodTimeout = nil
            state.output = nil
            return state.preservesOutputDirectory
        }

        // The Timeout callback fires on a cooperative-pool task, and terminal
        // buffers arrive on a TTS callback thread; deallocating the synthesizer
        // on either poisons the daemon. Force its final release onto the serial
        // queue that created it.
        Self.writeQueue.async {
            _ = self.$state.withValue { state -> AVSpeechSynthesizer? in
                defer { state.avSpeechSynthesizer = nil }
                return state.avSpeechSynthesizer
            }
        }

        guard !preservesOutputDirectory else { return }
        try? fileManager.removeItem(at: outputDirectoryURL)
    }

    private func retainForGracePeriod(preservingOutputDirectory: Bool) {
        // Deallocating a synthesizer that still has framework work
        // in flight – an unfinished write session or the trailing
        // completion block dispatched to the main queue – poisons the TTS
        // daemon; retain the session until the grace period lapses.
        // Recording the preservation decision here keeps a spurious
        // duplicate terminal buffer from deleting preserved output.
        Self.retainedSessions.projectedValue[id] = self
        $state.withValue { state in
            state.preservesOutputDirectory = preservingOutputDirectory
            state.gracePeriodTimeout = Timeout(after: .seconds(15)) { [weak self] in
                self?.releaseFromRetentionRegistry()
            }
        }
    }
}

private actor SynthesisThrottle {
    // MARK: - Properties

    static let shared = SynthesisThrottle()

    private var activeCount = 0
    private var lastFailureDate: Date?
    private var waiters = [(id: UUID, continuation: CheckedContinuation<Void, Never>)]()

    // MARK: - Computed Properties

    private var width: Int {
        // A recent synthesis failure indicates a wedge-prone daemon;
        // degrade to serial traffic for a cooldown window,
        // then self-heal back to full width.
        guard let lastFailureDate,
              Date.now.timeIntervalSince(lastFailureDate) < 60 else { return 3 }
        return 1
    }

    // MARK: - Methods

    func acquire() async {
        guard activeCount >= width else { return activeCount += 1 }

        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // The caller always holds a slot on return, so a cancelled
                // waiter still balances the caller's release;
                // resume at once if cancellation already occurred.
                guard !Task.isCancelled else {
                    activeCount += 1
                    return continuation.resume()
                }

                waiters.append((id, continuation))
            }
        } onCancel: {
            Task { await self.resumeCancelledWaiter(id) }
        }
    }

    func recordFailure() {
        lastFailureDate = .now
    }

    func release() {
        activeCount = max(0, activeCount - 1)
        while activeCount < width,
              !waiters.isEmpty {
            activeCount += 1
            waiters.removeFirst().continuation.resume()
        }
    }

    // MARK: - Auxiliary

    private func resumeCancelledWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        activeCount += 1
        waiters.remove(at: index).continuation.resume()
    }
}

private final class TextToSpeechVoiceInventory: @unchecked Sendable {
    // MARK: - Types

    private enum LoadState {
        case loaded([AVSpeechSynthesisVoice])
        case loading
        case notLoaded
    }

    // MARK: - Dependencies

    @SharedEvent(\.audioMessageCapabilityInventoryLoaded) private var audioMessageCapabilityInventoryLoaded

    // MARK: - Properties

    static let shared = TextToSpeechVoiceInventory()

    private static let loadQueue = DispatchQueue(
        label: "us.neotechnica.panther.tts-voice-inventory",
        qos: .userInitiated
    )

    @LockIsolated private var state: LoadState = .notLoaded
    @LockIsolated private var waiters = [UUID: CheckedContinuation<Void, Error>]()

    // MARK: - Computed Properties

    var loadedVoices: [AVSpeechSynthesisVoice]? {
        guard case let .loaded(voices) = state else { return nil }
        return voices
    }

    // MARK: - Methods

    func awaitLoaded(
        timeout: Duration = .seconds(5)
    ) async throws(Exception) {
        guard loadedVoices == nil else { return }
        load()

        let id = UUID()
        let timeoutRef = LockIsolated<Timeout?>(nil)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let isLoaded: Bool = $state.withValue { state in
                    guard case .loaded = state else {
                        $waiters.withValue { $0[id] = continuation }
                        return false
                    }

                    return true
                }

                guard !isLoaded else {
                    return continuation.resume()
                }

                timeoutRef.wrappedValue = Timeout(after: timeout) { [weak self] in
                    guard let self,
                          let waiter = $waiters.withValue({ $0.removeValue(forKey: id) }) else { return }
                    waiter.resume(throwing: Exception(
                        "Speech voice inventory unavailable.",
                        metadata: .init(sender: self)
                    ))
                }
            }

            timeoutRef.wrappedValue?.cancel()
        } catch {
            throw error as? Exception ?? .init(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    func invalidate() {
        // Reload only from a loaded state;
        // a load already in flight will publish fresh results.
        let shouldReload: Bool = $state.withValue { state in
            guard case .loaded = state else { return false }
            state = .notLoaded
            return true
        }

        guard shouldReload else { return }
        load()
    }

    func load() {
        let shouldLoad: Bool = $state.withValue { state in
            guard case .notLoaded = state else { return false }
            state = .loading
            return true
        }

        guard shouldLoad else { return }

        Self.loadQueue.async {
            let voices = AVSpeechSynthesisVoice.speechVoices()

            let drainedWaiters: [CheckedContinuation<Void, Error>] = self.$state.withValue { state in
                state = .loaded(voices)
                return self.$waiters.withValue { waiters in
                    defer { waiters.removeAll() }
                    return Array(waiters.values)
                }
            }

            drainedWaiters.forEach { $0.resume() }
            self.audioMessageCapabilityInventoryLoaded.send()
        }
    }
}

/// A namespace for managing the in-memory text-to-speech voice and language support caches.
enum TextToSpeechServiceCache {
    /// Removes every cached voice and language support value and reloads the voice inventory.
    static func clearCache() {
        _TextToSpeechServiceCache.clearCache()
        TextToSpeechVoiceInventory.shared.invalidate()
    }
}

private enum _TextToSpeechServiceCache {
    // MARK: - Properties

    // swiftlint:disable identifier_name
    private static let _cachedTextToSpeechSupportForLanguageCodes = LockIsolated<[String: Bool]?>(nil)
    private static let _cachedVoicesForLanguageCodes = LockIsolated<[String: AVSpeechSynthesisVoice]?>(nil)

    // MARK: - Computed Properties

    fileprivate static var cachedTextToSpeechSupportForLanguageCodes: [String: Bool]? {
        get { _cachedTextToSpeechSupportForLanguageCodes.wrappedValue }
        set { _cachedTextToSpeechSupportForLanguageCodes.wrappedValue = newValue }
    }

    fileprivate static var cachedVoicesForLanguageCodes: [String: AVSpeechSynthesisVoice]? {
        get { _cachedVoicesForLanguageCodes.wrappedValue }
        set { _cachedVoicesForLanguageCodes.wrappedValue = newValue }
    } // swiftlint:enable identifier_name

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedTextToSpeechSupportForLanguageCodes = nil
        cachedVoicesForLanguageCodes = nil
    }
}

// swiftlint:enable file_length
