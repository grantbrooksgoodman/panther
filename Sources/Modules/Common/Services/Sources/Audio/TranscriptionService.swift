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

struct TranscriptionService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.permission) private var permissionService: PermissionService

    // MARK: - Transcribe Audio File

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

        var didComplete = false
        var canComplete: Bool {
            guard !didComplete else { return false }
            didComplete = true
            return true
        }

        do {
            return try await withCheckedThrowingContinuation { continuation in
                recognizer.recognitionTask(with: request) { result, error in
                    guard let result else {
                        guard canComplete else { return }
                        return continuation.resume(throwing: Exception(
                            error,
                            metadata: .init(sender: self)
                        ))
                    }

                    guard canComplete,
                          result.isFinal else { return }
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

    func startLiveSession(languageCode: String) -> LiveTranscriptionSession? {
        guard permissionService.transcribePermissionStatus == .granted,
              isTranscriptionSupported(for: languageCode),
              let recognizer = SFSpeechRecognizer(
                  locale: Locale(identifier: languageCode)
              ) else { return nil }
        return .init(recognizer: recognizer)
    }

    // MARK: - Capabilities

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

    func append(_ buffer: AVAudioPCMBuffer) {
        guard case .pending = state else { return }
        recognitionRequest.append(buffer)
    }

    func cancel() {
        recognitionTask.wrappedValue?.cancel()
        complete(with: nil)
    }

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

enum TranscriptionServiceCache {
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
