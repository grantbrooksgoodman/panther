//
//  TextToSpeechService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFAudio
import Foundation

/* Proprietary */
import AppSubsystem

struct TextToSpeechService {
    // MARK: - Type Aliases

    private typealias DirectoryNames = AudioService.DirectoryNames
    private typealias FileNames = AudioService.FileNames

    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Read to File

    func readToFile(
        text: String,
        languageCode: String
    ) async throws(Exception) -> URL {
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

        if let voiceForLanguageCode = AVSpeechSynthesisVoice
            .speechVoices()
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

    func isTextToSpeechSupported(for languageCode: String) -> Bool {
        if let cachedValue = _TextToSpeechServiceCache.cachedTextToSpeechSupportForLanguageCodes?[languageCode] {
            return cachedValue
        }

        let isTextToSpeechSupported = AVSpeechSynthesisVoice
            .speechVoices()
            .contains(where: { $0.language.lowercased().hasPrefix(languageCode.lowercased()) })

        // swiftlint:disable:next identifier_name
        var cachedTextToSpeechSupportForLanguageCodes = _TextToSpeechServiceCache.cachedTextToSpeechSupportForLanguageCodes ?? [:]
        cachedTextToSpeechSupportForLanguageCodes[languageCode] = isTextToSpeechSupported
        _TextToSpeechServiceCache.cachedTextToSpeechSupportForLanguageCodes = cachedTextToSpeechSupportForLanguageCodes
        return isTextToSpeechSupported
    }

    // MARK: - Auxiliary

    private func getAudioFile(
        from text: String,
        languageCode: String
    ) async throws(Exception) -> URL {
        await SynthesisThrottle.shared.acquire()

        do {
            let outputDirectoryURL = fileManager.documentsDirectoryURL.appending(
                path: "\(DirectoryNames.textToSpeechOutputPrefix)\(UUID().uuidString)"
            )

            try fileManager.createDirectory(
                at: outputDirectoryURL,
                withIntermediateDirectories: true
            )

            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = highestQualityVoice(
                languageCode,
                mustIncludeAudioFileSettings: true
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

            if exception.isEqual(to: .timedOut) {
                await SynthesisThrottle.shared.recordTimeout()
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
        var timeout: Timeout?
    }

    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Properties

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
        try await withCheckedThrowingContinuation { continuation in
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

    private func complete(throwing exception: Exception) {
        let continuation: CheckedContinuation<URL, Error>? = $state.withValue { state in
            state.timeout?.cancel()
            state.timeout = nil

            defer { state.continuation = nil }
            return state.continuation
        }

        guard let continuation else { return }

        // Deallocating a synthesizer with an active write session poisons the TTS daemon;
        // retain the session until its terminal buffer arrives or the grace period lapses.
        Self.retainedSessions.projectedValue[id] = self
        $state.withValue { state in
            state.gracePeriodTimeout = Timeout(after: .seconds(15)) { [weak self] in
                self?.releaseFromRetentionRegistry()
            }
        }

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
            return continuation.resume(throwing: Exception(
                "Failed to generate output.",
                metadata: .init(sender: self)
            ))
        }

        continuation.resume(returning: outputFileURL)
    }

    private func releaseFromRetentionRegistry() {
        guard Self.retainedSessions.projectedValue.withValue({
            $0.removeValue(forKey: id)
        }) != nil else { return }

        $state.withValue { state in
            state.gracePeriodTimeout?.cancel()
            state.gracePeriodTimeout = nil
            state.output = nil
        }

        try? fileManager.removeItem(at: outputDirectoryURL)
    }
}

private actor SynthesisThrottle {
    // MARK: - Properties

    static let shared = SynthesisThrottle()

    private var activeCount = 0
    private var lastTimeoutDate: Date?
    private var waiters = [CheckedContinuation<Void, Never>]()

    // MARK: - Computed Properties

    private var width: Int {
        // A timeout indicates a wedge-prone daemon; degrade to serial traffic for a cooldown window.
        guard let lastTimeoutDate,
              Date.now.timeIntervalSince(lastTimeoutDate) < 60 else { return 3 }
        return 1
    }

    // MARK: - Methods

    func acquire() async {
        guard activeCount >= width else { return activeCount += 1 }
        await withCheckedContinuation { waiters.append($0) }
    }

    func recordTimeout() {
        lastTimeoutDate = .now
    }

    func release() {
        activeCount = max(0, activeCount - 1)
        while activeCount < width,
              !waiters.isEmpty {
            activeCount += 1
            waiters.removeFirst().resume()
        }
    }
}

enum TextToSpeechServiceCache {
    static func clearCache() {
        _TextToSpeechServiceCache.clearCache()
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
