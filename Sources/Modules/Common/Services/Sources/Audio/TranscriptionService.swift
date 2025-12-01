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

    func transcribeAudioFile(at url: URL, languageCode: String) async -> Callback<String, Exception> {
        guard permissionService.transcribePermissionStatus == .granted else {
            return .failure(.init("Not authorized for transcription.", metadata: .init(sender: self)))
        }

        guard isTranscriptionSupported(for: languageCode) else {
            return .failure(.init(
                "Transcription is not supported for the specified language code.",
                userInfo: ["LanguageCode": languageCode],
                metadata: .init(sender: self)
            ))
        }

        let locale = Locale(identifier: languageCode)

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.addsPunctuation = true
        request.shouldReportPartialResults = false

        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return .failure(.init(
                "Unsupported locale for transcription.",
                userInfo: ["LocaleIdentifier": locale.identifier],
                metadata: .init(sender: self)
            ))
        }

        return await withCheckedContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                guard let result else {
                    continuation.resume(returning: .failure(.init(
                        error,
                        metadata: .init(sender: self)
                    )))
                    return
                }

                guard result.isFinal else {
                    continuation.resume(returning: .failure(.init(
                        "Returned transcription wasn't final.",
                        metadata: .init(sender: self)
                    )))
                    return
                }

                continuation.resume(returning: .success(result.bestTranscription.formattedString))
            }
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
    // MARK: - Types

    private enum CacheKey: String, CaseIterable {
        case transcriptionSupportForLanguageCodes
    }

    // MARK: - Properties

    // swiftlint:disable:next identifier_name
    @Cached(CacheKey.transcriptionSupportForLanguageCodes) fileprivate static var cachedTranscriptionSupportForLanguageCodes: [String: Bool]?

    // MARK: - Clear Cache

    fileprivate static func clearCache() {
        cachedTranscriptionSupportForLanguageCodes = nil
    }
}
