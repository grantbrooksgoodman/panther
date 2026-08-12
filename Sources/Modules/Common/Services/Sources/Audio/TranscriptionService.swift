//
//  TranscriptionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFAudio
import Foundation
import Speech

/* Proprietary */
import AppSubsystem

/// Use ``TranscriptionService`` to transcribe recorded audio to text.
///
/// The service transcribes audio files, hosts live transcription sessions for in-progress
/// recordings, and reports which languages support transcription. Language support lookups are
/// cached in memory.
struct TranscriptionService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.permission) private var permissionService: PermissionService

    // MARK: - Transcribe Audio File

    /// Transcribes the audio file at the given URL.
    ///
    /// Transcription includes punctuation. The operation times out if no final result arrives
    /// within 30 seconds.
    ///
    /// - Parameters:
    ///   - url: The URL of the audio file to transcribe.
    ///   - languageCode: The language code of the audio content.
    ///
    /// - Returns: The transcribed text.
    ///
    /// - Throws: An `Exception` if transcription permission has not been granted, if
    ///   transcription is not supported for the given language code, if recognition fails, or
    ///   if the operation times out.
    func transcribeAudioFile(
        at url: URL,
        languageCode: String
    ) async throws(Exception) -> String {
        guard permissionService.transcribePermissionStatus == .granted else {
            throw Exception(
                "Not authorized for transcription.",
                metadata: .init(sender: self)
            )
        }

        guard isTranscriptionSupported(for: languageCode) else {
            throw Exception(
                "Transcription is not supported for the specified language code.",
                userInfo: ["LanguageCode": languageCode],
                metadata: .init(sender: self)
            )
        }

        let locale = Locale(identifier: languageCode)

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.addsPunctuation = true
        request.shouldReportPartialResults = false

        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw Exception(
                "Unsupported locale for transcription.",
                userInfo: ["LocaleIdentifier": locale.identifier],
                metadata: .init(sender: self)
            )
        }

        let didComplete = LockIsolated(false)
        var canComplete: Bool {
            didComplete.projectedValue.withValue {
                guard !$0 else { return false }
                $0 = true
                return true
            }
        }

        let recognitionTask = LockIsolated<SFSpeechRecognitionTask?>(nil)
        let timeout = LockIsolated<Timeout?>(nil)

        do {
            return try await withCheckedThrowingContinuation { continuation in
                timeout.wrappedValue = Timeout(after: .seconds(30)) {
                    guard canComplete else { return }
                    recognitionTask.wrappedValue?.cancel()
                    continuation.resume(throwing: Exception.timedOut(
                        metadata: .init(sender: self)
                    ))
                }

                recognitionTask.wrappedValue = recognizer.recognitionTask(
                    with: request
                ) { result, error in
                    guard let result else {
                        guard canComplete else { return }
                        timeout.wrappedValue?.cancel()

                        return continuation.resume(throwing: Exception(
                            error,
                            metadata: .init(sender: self)
                        ))
                    }

                    guard result.isFinal,
                          canComplete else { return }
                    timeout.wrappedValue?.cancel()
                    continuation.resume(
                        returning: result.bestTranscription.formattedString
                    )
                }
            }
        } catch {
            guard let exception = error as? Exception else {
                throw Exception(
                    error,
                    metadata: .init(sender: self)
                )
            }

            throw exception
        }
    }

    // MARK: - Start Live Session

    /// Starts a live transcription session for the given language code.
    ///
    /// - Parameter languageCode: The language code of the audio content.
    ///
    /// - Returns: A new session ready to receive audio buffers; otherwise, `nil` if
    ///   transcription permission has not been granted or transcription is not supported for
    ///   the given language code.
    func startLiveSession(languageCode: String) -> LiveTranscriptionSession? {
        guard permissionService.transcribePermissionStatus == .granted,
              isTranscriptionSupported(for: languageCode),
              let recognizer = SFSpeechRecognizer(
                  locale: Locale(identifier: languageCode)
              ) else { return nil }
        return .init(recognizer: recognizer)
    }

    // MARK: - Capabilities

    /// Returns a Boolean value that indicates whether transcription is supported for the given
    /// language code.
    ///
    /// Support is determined by whether any supported recognition locale matches the given
    /// code. Results are cached in memory per language code.
    ///
    /// - Parameter languageCode: The language code for which to check support.
    ///
    /// - Returns: `true` if transcription is supported for the given language code; otherwise,
    ///   `false`.
    func isTranscriptionSupported(for languageCode: String) -> Bool {
        if let cachedValue = _TranscriptionServiceCache.cachedTranscriptionSupportForLanguageCodes?[languageCode] {
            return cachedValue
        }

        let isTranscriptionSupported = SFSpeechRecognizer
            .supportedLocales()
            .compactMap(\.language.languageCode?.identifier)
            .contains(where: { $0.hasPrefix(languageCode.lowercased()) })

        // swiftlint:disable:next identifier_name
        var cachedTranscriptionSupportForLanguageCodes = _TranscriptionServiceCache.cachedTranscriptionSupportForLanguageCodes ?? [:]
        cachedTranscriptionSupportForLanguageCodes[languageCode] = isTranscriptionSupported
        _TranscriptionServiceCache.cachedTranscriptionSupportForLanguageCodes = cachedTranscriptionSupportForLanguageCodes
        return isTranscriptionSupported
    }
}

/// A speech recognition session that transcribes audio as it is captured.
///
/// Obtain a session from ``TranscriptionService/startLiveSession(languageCode:)``, then feed it
/// audio buffers with ``append(_:)`` – typically from the `bufferSink` closure of
/// ``RecordingService/startRecording(bufferSink:)``. Call ``finish()`` to end the session and
/// retrieve the transcription, or ``cancel()`` to discard it.
final class LiveTranscriptionSession: @unchecked Sendable {
    // MARK: - Types

    private enum State {
        case completed(transcription: String?)
        case pending
        case waiting(CheckedContinuation<String?, Never>)
    }

    // MARK: - Properties

    private let latestTranscription = LockIsolated<String?>(nil)
    private let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    private let recognitionTask = LockIsolated<SFSpeechRecognitionTask?>(nil)
    private let speechRecognizer: SFSpeechRecognizer
    private let timeout = LockIsolated<Timeout?>(nil)

    @LockIsolated private var state: State = .pending

    // MARK: - Object Lifecycle

    fileprivate init(recognizer: SFSpeechRecognizer) {
        speechRecognizer = recognizer
        recognitionRequest.addsPunctuation = true
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask.wrappedValue = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                latestTranscription.wrappedValue = result.bestTranscription.formattedString
            }

            guard result?.isFinal == true || error != nil else { return }
            complete(with: error == nil ? latestTranscription.wrappedValue : nil)
        }
    }

    deinit {
        recognitionTask.wrappedValue?.cancel()
    }

    // MARK: - Methods

    /// Appends an audio buffer to the recognition request.
    ///
    /// Buffers appended after ``finish()`` or ``cancel()`` has been called are ignored.
    ///
    /// - Parameter buffer: The captured audio buffer to transcribe.
    func append(_ buffer: AVAudioPCMBuffer) {
        guard case .pending = state else { return }
        recognitionRequest.append(buffer)
    }

    /// Cancels the session, discarding any transcription.
    func cancel() {
        recognitionTask.wrappedValue?.cancel()
        complete(with: nil)
    }

    /// Ends audio input and returns the final transcription.
    ///
    /// If the final recognition result does not arrive within five seconds, this method returns
    /// `nil`.
    ///
    /// - Returns: The final transcription; otherwise, `nil` if recognition failed, the session
    ///   was canceled, or the transcription is empty.
    func finish() async -> String? {
        recognitionRequest.endAudio()

        let transcription: String? = await withCheckedContinuation { continuation in
            let action: (() -> Void)? = $state.withValue {
                switch $0 {
                case let .completed(transcription):
                    return { continuation.resume(returning: transcription) }

                case .pending:
                    $0 = .waiting(continuation)
                    return nil

                case .waiting:
                    return { continuation.resume(returning: nil) }
                }
            }

            guard let action else {
                return timeout.wrappedValue = Timeout(after: .seconds(5)) { [weak self] in
                    self?.complete(with: nil)
                }
            }

            action()
        }

        guard let transcription,
              !transcription.trimmingBorderedWhitespace.isEmpty else { return nil }

        return transcription
    }

    // MARK: - Auxiliary

    private func complete(with transcription: String?) {
        timeout.wrappedValue?.cancel()
        timeout.wrappedValue = nil

        let action: (() -> Void)? = $state.withValue {
            switch $0 {
            case .completed:
                return nil

            case .pending:
                $0 = .completed(transcription: transcription)
                return nil

            case let .waiting(continuation):
                $0 = .completed(transcription: transcription)
                return { continuation.resume(returning: transcription) }
            }
        }

        action?()
    }
}

/// A namespace for managing the in-memory transcription language support cache.
enum TranscriptionServiceCache {
    /// Removes every cached language support value.
    static func clearCache() {
        _TranscriptionServiceCache.clearCache()
    }
}

private enum _TranscriptionServiceCache {
    // MARK: - Properties

    // swiftlint:disable identifier_name
    private static let _cachedTranscriptionSupportForLanguageCodes = LockIsolated<[String: Bool]?>(nil)

    // MARK: - Computed Properties

    fileprivate static var cachedTranscriptionSupportForLanguageCodes: [String: Bool]? {
        get { _cachedTranscriptionSupportForLanguageCodes.wrappedValue }
        set { _cachedTranscriptionSupportForLanguageCodes.wrappedValue = newValue }
    } // swiftlint:enable identifier_name

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedTranscriptionSupportForLanguageCodes = nil
    }
}
