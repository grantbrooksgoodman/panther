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
        case translations
        case readDate
        case sentDate
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        var readDateString = String.bangQualifiedEmpty
        if let readDate {
            readDateString = dateFormatter.string(from: readDate)
        }

        return [
            Keys.id.rawValue: id,
            Keys.fromAccountID.rawValue: fromAccountID,
            Keys.contentType.rawValue: contentType.rawValue,
            Keys.translations.rawValue: translations?.map(\.reference.hostingKey) ?? .bangQualifiedEmpty,
            Keys.readDate.rawValue: readDateString,
            Keys.sentDate.rawValue: dateFormatter.string(from: sentDate),
        ]
    }

    // MARK: - Methods

    public static func canDecode(from data: [String: Any]) -> Bool {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter

        guard data[Keys.id.rawValue] as? String != nil,
              data[Keys.fromAccountID.rawValue] as? String != nil,
              let contentTypeString = data[Keys.contentType.rawValue] as? String,
              ContentType(rawValue: contentTypeString) != nil,
              data[Keys.translations.rawValue] as? [String] != nil,
              data[Keys.readDate.rawValue] as? String != nil,
              let sentDateString = data[Keys.sentDate.rawValue] as? String,
              dateFormatter.date(from: sentDateString) != nil else { return false }

        return true
    }

    public static func decode(from data: [String: Any]) async -> Callback<Message, Exception> {
        @Dependency(\.timestampDateFormatter) var dateFormatter: DateFormatter
        @Dependency(\.networking.services.message) var messageService: MessageService
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        guard let id = data[Keys.id.rawValue] as? String,
              let fromAccountID = data[Keys.fromAccountID.rawValue] as? String,
              let contentTypeString = data[Keys.contentType.rawValue] as? String,
              let contentType = ContentType(rawValue: contentTypeString),
              let translationReferences = data[Keys.translations.rawValue] as? [String],
              let readDateString = data[Keys.readDate.rawValue] as? String,
              let sentDateString = data[Keys.sentDate.rawValue] as? String,
              let sentDate = dateFormatter.date(from: sentDateString) else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        var readDate: Date?
        if !readDateString.isBangQualifiedEmpty {
            readDate = dateFormatter.date(from: readDateString)
        }

        func decodedMessage(_ translations: [Translation]?) -> Message {
            .init(
                id,
                fromAccountID: fromAccountID,
                contentType: contentType,
                richContent: nil,
                translations: translations,
                readDate: readDate,
                sentDate: sentDate
            )
        }

        guard contentType != .media else {
            return await messageService.media.getMediaComponent(for: decodedMessage(nil))
        }

        let languageCode = userSession.currentUser?.languageCode ?? RuntimeStorage.languageCode
        let references = translationReferences.compactMap { TranslationReference($0) }

        /* If all the translations are originally from the current language code,
         makeIdempotent will only decode the first reference and return a translation built from the original input. */
        let getTranslationsResult = await getTranslations(
            references: references,
            makeIdempotent: references.allSatisfy { $0.languagePair.from == languageCode } && references.count > 1
        )

        switch getTranslationsResult {
        case let .success(translations):
            let matchingLanguage = translations.filter { $0.languagePair.to == languageCode }
            let notMatchingLanguage = translations.filter { $0.languagePair.to != languageCode }
            let sortedTranslations = matchingLanguage + notMatchingLanguage

            guard contentType != .audio else {
                return await messageService.audio.getAudioComponent(for: decodedMessage(sortedTranslations))
            }

            return .success(decodedMessage(sortedTranslations))

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private static func getTranslations(
        references: [TranslationReference],
        makeIdempotent: Bool
    ) async -> Callback<[Translation], Exception> {
        func getTranslation(_ reference: TranslationReference) async -> Callback<Translation, Exception> {
            @Dependency(\.networking.services.translation.archiver) var translationArchiver: HostedTranslationArchiver

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

        guard !references.isEmpty,
              let firstReference = references.first else {
            return .failure(.init(
                "No translation references provided.",
                metadata: [self, #file, #function, #line]
            ))
        }

        let references = makeIdempotent ? [firstReference] : references

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
