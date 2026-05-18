//
//  Message+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking
import Translator

extension Message: Serializable {
    // MARK: - Type Aliases

    private typealias Keys = SerializableKey

    // MARK: - Types

    enum SerializableKey: String {
        case id
        case fromAccountID = "fromAccount"
        case contentType
        case translationReferences = "translations"
        case readReceipts
        case sentDate
    }

    // MARK: - Properties

    var encoded: [String: Any] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        return [
            Keys.id.rawValue: id,
            Keys.fromAccountID.rawValue: fromAccountID,
            Keys.contentType.rawValue: contentType.mediaFileID == nil ? contentType.rawValue : "\(contentType.rawValue) – \(contentType.mediaFileID!)",
            Keys.translationReferences.rawValue: translationReferences?.map(\.hostingKey) ?? .bangQualifiedEmpty,
            Keys.readReceipts.rawValue: readReceipts?.map(\.encoded) ?? .bangQualifiedEmpty,
            Keys.sentDate.rawValue: dateFormatter.string(from: sentDate),
        ]
    }

    // MARK: - Init

    init(
        from data: [String: Any]
    ) async throws(Exception) {
        @Dependency(\.clientSession.user.currentUser) var currentUser: User?
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        @Dependency(\.networking.messageService) var messageService: MessageService

        guard let id = data[Keys.id.rawValue] as? String,
              let fromAccountID = data[Keys.fromAccountID.rawValue] as? String,
              let contentTypeString = data[Keys.contentType.rawValue] as? String,
              let contentType = HostedContentType(hostedValue: contentTypeString),
              let translationReferenceStrings = data[Keys.translationReferences.rawValue] as? [String],
              let encodedReadReceipts = data[Keys.readReceipts.rawValue] as? [String],
              let sentDateString = data[Keys.sentDate.rawValue] as? String,
              let sentDate = dateFormatter.date(from: sentDateString) else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        var readReceipts: [ReadReceipt]?
        if !encodedReadReceipts.isBangQualifiedEmpty {
            readReceipts = try await encodedReadReceipts.parallelMap {
                try await ReadReceipt(from: $0)
            }
        }

        let languageCode = currentUser?.languageCode ?? RuntimeStorage.languageCode
        let translationReferences: [TranslationReference]? = translationReferenceStrings.isEmpty ? nil : translationReferenceStrings.compactMap { .init($0) }

        switch contentType {
        case .audio:
            let translations = try await Self.getTranslations(
                languageCode: languageCode,
                referenceStrings: translationReferenceStrings,
                fromAccountID: fromAccountID
            )

            guard let translation = translations.first else {
                throw .Networking.decodingFailed(
                    data: data,
                    .init(sender: Self.self)
                )
            }

            self = try await .init(
                id,
                fromAccountID: fromAccountID,
                contentType: contentType,
                richContent: .audio([
                    messageService.audio.getAudioComponent(
                        messageID: id,
                        isFromCurrentUser: fromAccountID == User.currentUserID,
                        localAudioFilePath: .init(
                            messageID: id,
                            translation: translation
                        ),
                        translation: translation
                    ).get(),
                ]),
                translationReferences: translationReferences,
                translations: translations,
                readReceipts: readReceipts,
                sentDate: sentDate
            )

        case .media:
            guard let localMediaFilePath = LocalMediaFilePath(contentType: contentType) else {
                throw .Networking.decodingFailed(
                    data: data,
                    .init(sender: Self.self)
                )
            }

            self = try await .init(
                id,
                fromAccountID: fromAccountID,
                contentType: contentType,
                richContent: .media(
                    messageService.media.getMediaComponent(
                        messageID: id,
                        localMediaFilePath: localMediaFilePath
                    ).get()
                ),
                translationReferences: translationReferences,
                translations: nil,
                readReceipts: readReceipts,
                sentDate: sentDate
            )

        case .text:
            self = try await .init(
                id,
                fromAccountID: fromAccountID,
                contentType: contentType,
                richContent: nil,
                translationReferences: translationReferences,
                translations: Self.getTranslations(
                    languageCode: languageCode,
                    referenceStrings: translationReferenceStrings,
                    fromAccountID: fromAccountID
                ),
                readReceipts: readReceipts,
                sentDate: sentDate
            )
        }
    }

    // MARK: - Methods

    static func canDecode(
        from data: [String: Any]
    ) -> Bool {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        guard data[Keys.id.rawValue] is String,
              data[Keys.fromAccountID.rawValue] is String,
              let contentTypeString = data[Keys.contentType.rawValue] as? String,
              let hostedContentType = HostedContentType(hostedValue: contentTypeString),
              let encodedReadReceipts = data[Keys.readReceipts.rawValue] as? [String],
              encodedReadReceipts.isBangQualifiedEmpty || encodedReadReceipts.allSatisfy({ ReadReceipt.canDecode(from: $0) }),
              let sentDateString = data[Keys.sentDate.rawValue] as? String,
              dateFormatter.date(from: sentDateString) != nil,
              let translationReferenceStrings = data[Keys.translationReferences.rawValue] as? [String] else { return false }

        if hostedContentType == .text,
           translationReferenceStrings.isBangQualifiedEmpty {
            return false
        }

        return true
    }

    // MARK: - Auxiliary

    private static func getTranslation(
        _ reference: TranslationReference
    ) async throws(Exception) -> Translation {
        let translation = try await Translation(from: reference)

        if let exception = TranslationValidator.validate(
            translation: translation,
            metadata: .init(sender: Self.self)
        ) {
            throw exception
        }

        return translation
    }

    private static func getTranslations(
        languageCode: String,
        referenceStrings: [String],
        fromAccountID: String
    ) async throws(Exception) -> [Translation] {
        let isFromCurrentUser = fromAccountID == User.currentUserID
        let translationReferences = referenceStrings.compactMap { TranslationReference($0) }
        var filteredReferences = translationReferences

        let firstMatchingSource = filteredReferences.first(where: { $0.languagePair.from == languageCode })
        let firstNearlyMatchingSource = filteredReferences.first(where: \.languagePair.from.isUserReadableLanguageCode)

        let firstMatchingTarget = filteredReferences.first(where: { $0.languagePair.to == languageCode })
        let firstNearlyMatchingTarget = filteredReferences.first(where: \.languagePair.to.isUserReadableLanguageCode)

        var reference = firstMatchingTarget ?? firstMatchingSource ?? firstNearlyMatchingTarget ?? firstNearlyMatchingSource
        if isFromCurrentUser {
            reference = firstMatchingSource ?? firstNearlyMatchingSource ?? firstMatchingTarget ?? firstNearlyMatchingTarget
        }

        filteredReferences = reference == nil ? filteredReferences : [reference!]
        let translations = try await getTranslations(
            references: filteredReferences
        )

        switch isFromCurrentUser {
        case true:
            let matchingLanguage = translations.filter(\.languagePair.from.isUserReadableLanguageCode)
            let notMatchingLanguage = translations.filter { !$0.languagePair.from.isUserReadableLanguageCode }
            return matchingLanguage + notMatchingLanguage

        case false:
            if firstMatchingTarget == nil,
               (firstMatchingSource ?? firstNearlyMatchingSource) != nil {
                return translations.map {
                    Translation(
                        input: $0.input,
                        output: $0.input.value,
                        languagePair: .init(
                            from: $0.languagePair.from,
                            to: $0.languagePair.from
                        )
                    )
                }
            }

            let matchingLanguage = translations.filter(\.languagePair.to.isUserReadableLanguageCode)
            let notMatchingLanguage = translations.filter { !$0.languagePair.to.isUserReadableLanguageCode }
            return matchingLanguage + notMatchingLanguage
        }
    }

    private static func getTranslations(
        references: [TranslationReference]
    ) async throws(Exception) -> [Translation] {
        guard !references.isEmpty else {
            throw Exception(
                "No translation references provided.",
                metadata: .init(sender: Self.self)
            )
        }

        let translations = try await references.parallelMap {
            try await Self.getTranslation($0)
        }

        guard translations.isWellFormed else {
            throw Exception(
                "Translations fail validation.",
                metadata: .init(sender: Self.self)
            )
        }

        return translations
    }
}

private extension String {
    var isUserReadableLanguageCode: Bool {
        @Dependency(\.clientSession.user.currentUser) var currentUser: User?
        let currentUserLanguageCode = currentUser?.languageCode ?? RuntimeStorage.languageCode
        return self == currentUserLanguageCode || currentUser?.previousLanguageCodes?.contains(self) == true
    }
}
