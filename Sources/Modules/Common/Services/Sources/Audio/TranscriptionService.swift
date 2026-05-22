//
//  TranscriptionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
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
