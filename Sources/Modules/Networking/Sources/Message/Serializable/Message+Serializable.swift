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

    public typealias T = Message
    private typealias Keys = SerializationKeys

    // MARK: - Types

    public enum SerializationKeys: String {
        case id
        case fromAccountID = "fromAccount"
        case contentType
        case translationReferences = "translations"
        case readReceipts
        case sentDate
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        return [
            Keys.id.rawValue: id,
            Keys.fromAccountID.rawValue: fromAccountID,
            Keys.contentType.rawValue: contentType.rawValue,
            Keys.translationReferences.rawValue: translationReferences?.map(\.hostingKey) ?? .bangQualifiedEmpty,
            Keys.readReceipts.rawValue: readReceipts?.map(\.encoded) ?? .bangQualifiedEmpty,
            Keys.sentDate.rawValue: dateFormatter.string(from: sentDate),
        ]
    }

    // MARK: - Methods

    public static func canDecode(from data: [String: Any]) -> Bool {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        guard data[Keys.id.rawValue] is String,
              data[Keys.fromAccountID.rawValue] is String,
              let contentTypeString = data[Keys.contentType.rawValue] as? String,
              HostedContentType(rawValue: contentTypeString) != nil,
              data[Keys.translationReferences.rawValue] is [String],
              let encodedReadReceipts = data[Keys.readReceipts.rawValue] as? [String],
              encodedReadReceipts.isBangQualifiedEmpty || encodedReadReceipts.allSatisfy({ ReadReceipt.canDecode(from: $0) }),
              let sentDateString = data[Keys.sentDate.rawValue] as? String,
              dateFormatter.date(from: sentDateString) != nil else { return false }

        return true
    }

    public static func decode(from data: [String: Any]) async -> Callback<Message, Exception> {
        @Dependency(\.clientSession.user.currentUser) var currentUser: User?
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        @Dependency(\.networking.messageService) var messageService: MessageService

        guard let id = data[Keys.id.rawValue] as? String,
              let fromAccountID = data[Keys.fromAccountID.rawValue] as? String,
              let contentTypeString = data[Keys.contentType.rawValue] as? String,
              let contentType = HostedContentType(rawValue: contentTypeString),
              let translationReferenceStrings = data[Keys.translationReferences.rawValue] as? [String],
              let encodedReadReceipts = data[Keys.readReceipts.rawValue] as? [String],
              let sentDateString = data[Keys.sentDate.rawValue] as? String,
              let sentDate = dateFormatter.date(from: sentDateString) else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        var readReceipts: [ReadReceipt]?
        if !encodedReadReceipts.isBangQualifiedEmpty {
            readReceipts = .init()
            for encodedReadReceipt in encodedReadReceipts {
                let decodeResult = await ReadReceipt.decode(from: encodedReadReceipt)
                switch decodeResult {
                case let .success(readReceipt): readReceipts?.append(readReceipt)
                case let .failure(exception): return .failure(exception)
                }
            }
        }

        func decodedMessage(_ translations: [Translation]?) -> Message {
            .init(
                id,
                fromAccountID: fromAccountID,
                contentType: contentType,
                richContent: nil,
                translationReferences: translationReferenceStrings.isEmpty ? nil : translationReferenceStrings.compactMap { .init($0) },
                translations: translations,
                readReceipts: readReceipts,
                sentDate: sentDate
            )
        }

        func getAndApplyTranslations() async -> Callback<Message, Exception> {
            let languageCode = currentUser?.languageCode ?? RuntimeStorage.languageCode
            var references = translationReferenceStrings.compactMap { TranslationReference($0) }

            if let firstMatchingTarget = references.first(where: { $0.languagePair.to == languageCode }) {
                references = [firstMatchingTarget]
            } else if let firstMatchingSource = references.first(where: { $0.languagePair.from == languageCode }) {
                references = [firstMatchingSource]
            }

            let getTranslationsResult = await getTranslations(references: references)

            switch getTranslationsResult {
            case let .success(translations):
                let matchingLanguage = translations.filter { $0.languagePair.to == languageCode }
                let notMatchingLanguage = translations.filter { $0.languagePair.to != languageCode }
                let sortedTranslations = matchingLanguage + notMatchingLanguage

                return .success(decodedMessage(sortedTranslations))

            case let .failure(exception):
                return .failure(exception)
            }
        }

        switch contentType {
        case .media(.audio):
            let getAndApplyTranslationsResult = await getAndApplyTranslations()

            switch getAndApplyTranslationsResult {
            case let .success(message):
                return await messageService.audio.getAudioComponent(for: message)

            case let .failure(exception):
                return .failure(exception)
            }

        case .media:
            return await messageService.media.getMediaComponent(for: decodedMessage(nil))

        case .text:
            return await getAndApplyTranslations()
        }
    }

    private static func getTranslations(references: [TranslationReference]) async -> Callback<[Translation], Exception> {
        func getTranslation(_ reference: TranslationReference) async -> Callback<Translation, Exception> {
            let decodeResult = await Translation.decode(from: reference)

            switch decodeResult {
            case let .success(translation):
                if let exception = TranslationValidator.validate(
                    translation: translation,
                    metadata: [self, #file, #function, #line]
                ) {
                    return .failure(exception)
                }

                return .success(translation)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        guard !references.isEmpty else {
            return .failure(.init(
                "No translation references provided.",
                metadata: [self, #file, #function, #line]
            ))
        }

        var translations = [Translation]()
        for reference in references {
            let getTranslationResult = await getTranslation(reference)

            switch getTranslationResult {
            case let .success(translation):
                translations.append(translation)

            case let .failure(exception):
                return .failure(exception)
            }
        }

        guard translations.count == references.count else {
            return .failure(.init(
                "Mismatched ratio returned.",
                metadata: [self, #file, #function, #line]
            ))
        }

        guard translations.isWellFormed else {
            return .failure(.init(
                "Translations fail validation.",
                metadata: [self, #file, #function, #line]
            ))
        }

        return .success(translations)
    }
}
