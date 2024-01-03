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

/* 3rd-party */
import Redux

public struct TranscriptionService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.permission) private var permissionService: PermissionService

    // MARK: - Transcribe Audio File

    public func transcribeAudioFile(at url: URL, languageCode: String) async -> Callback<String, Exception> {
        guard permissionService.transcribePermissionStatus == .granted else {
            return .failure(.init("Not authorized for transcription.", metadata: [self, #file, #function, #line]))
        }

        guard isTranscriptionSupported(for: languageCode) else {
            return .failure(.init(
                "Transcription is not supported for the specified language code.",
                extraParams: ["LanguageCode": languageCode],
                metadata: [self, #file, #function, #line]
            ))
        }

        let locale = Locale(identifier: languageCode)

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.addsPunctuation = true
        request.shouldReportPartialResults = false

        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return .failure(.init(
                "Unsupported locale for transcription.",
                extraParams: ["LocaleIdentifier": locale.identifier],
                metadata: [self, #file, #function, #line]
            ))
        }

        return await withCheckedContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                guard let result else {
                    continuation.resume(returning: .failure(.init(
                        error,
                        metadata: [self, #file, #function, #line]
                    )))
                    return
                }

                guard result.isFinal else {
                    continuation.resume(returning: .failure(.init(
                        "Returned transcription wasn't final.",
                        metadata: [self, #file, #function, #line]
                    )))
                    return
                }

                continuation.resume(returning: .success(result.bestTranscription.formattedString))
            }
        }
    }

    // MARK: - Capabilities

    public func isTranscriptionSupported(for languageCode: String) -> Bool {
        SFSpeechRecognizer
            .supportedLocales()
            .compactMap(\.language.languageCode?.identifier)
            .contains(where: { $0.hasPrefix(languageCode.lowercased()) })
    }
}
