//
//  Message+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
import Translator

extension Message: Serializable {
    // MARK: - Type Aliases

    public typealias T = Message
    private typealias Keys = SerializationKeys

    // MARK: - Types

    public enum SerializationKeys: String {
        case id
        case fromAccountID = "fromAccount"
        case hasAudioComponent
        case hasImageComponent
        case translations
        case readDate
        case sentDate
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter

        var readDateString = String.bangQualifiedEmpty
        if let readDate {
            readDateString = dateFormatter.string(from: readDate)
        }

        return [
            Keys.id.rawValue: id,
            Keys.fromAccountID.rawValue: fromAccountID,
            Keys.hasAudioComponent.rawValue: hasAudioComponent,
            Keys.hasImageComponent.rawValue: hasImageComponent,
            Keys.translations.rawValue: translations?.map(\.reference.hostingKey) ?? .bangQualifiedEmpty,
            Keys.readDate.rawValue: readDateString,
            Keys.sentDate.rawValue: dateFormatter.string(from: sentDate),
        ]
    }

    // MARK: - Methods

    public static func canDecode(from data: [String: Any]) -> Bool {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter

        guard data[Keys.id.rawValue] as? String != nil,
              data[Keys.fromAccountID.rawValue] as? String != nil,
              let hasAudioComponentString = data[Keys.hasAudioComponent.rawValue] as? String,
              hasAudioComponentString == "true" || hasAudioComponentString == "false",
              let hasImageComponentString = data[Keys.hasImageComponent.rawValue] as? String,
              hasImageComponentString == "true" || hasImageComponentString == "false",
              data[Keys.translations.rawValue] as? [String] != nil,
              data[Keys.readDate.rawValue] as? String != nil,
              let sentDateString = data[Keys.sentDate.rawValue] as? String,
              dateFormatter.date(from: sentDateString) != nil else { return false }

        return true
    }

    public static func decode(from data: [String: Any]) async -> Callback<Message, Exception> {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
        @Dependency(\.networking.services.message) var messageService: MessageService
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        guard let id = data[Keys.id.rawValue] as? String,
              let fromAccountID = data[Keys.fromAccountID.rawValue] as? String,
              let hasAudioComponentString = data[Keys.hasAudioComponent.rawValue] as? String,
              hasAudioComponentString == "true" || hasAudioComponentString == "false",
              let hasImageComponentString = data[Keys.hasImageComponent.rawValue] as? String,
              hasImageComponentString == "true" || hasImageComponentString == "false",
              let translationReferences = data[Keys.translations.rawValue] as? [String],
              let readDateString = data[Keys.readDate.rawValue] as? String,
              let sentDateString = data[Keys.sentDate.rawValue] as? String,
              let sentDate = dateFormatter.date(from: sentDateString) else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        let hasAudioComponent = hasAudioComponentString == "true" ? true : false
        let hasImageComponent = hasImageComponentString == "true" ? true : false

        var readDate: Date?
        if !readDateString.isBangQualifiedEmpty {
            readDate = dateFormatter.date(from: readDateString)
        }

        func decodedMessage(_ translations: [Translation]?) -> Message {
            .init(
                id,
                fromAccountID: fromAccountID,
                hasAudioComponent: hasAudioComponent,
                hasImageComponent: hasImageComponent,
                audioComponents: nil,
                image: nil,
                translations: translations,
                readDate: readDate,
                sentDate: sentDate
            )
        }

        guard !hasImageComponent else {
            return await messageService.image.getImageComponent(for: decodedMessage(nil))
        }

        let languageCode = userSession.currentUser?.languageCode ?? RuntimeStorage.languageCode
        let references = translationReferences.compactMap { TranslationReference($0) }

        // NIT: Fuzzy on what effect making translations idempotent has.
        let getTranslationsResult = await getTranslations(
            references: references,
            makeIdempotent: references.allSatisfy { $0.languagePair.from == languageCode } && references.count > 1
        )

        switch getTranslationsResult {
        case let .success(translations):
            let matchingLanguage = translations.filter { $0.languagePair.to == languageCode }
            let notMatchingLanguage = translations.filter { $0.languagePair.to != languageCode }
            let sortedTranslations = matchingLanguage + notMatchingLanguage

            guard !hasAudioComponent else {
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

            func validateAndReturn(_ translation: Translation) -> Callback<Translation, Exception> {
                if let exception = TranslationValidator.validate(
                    translation: translation,
                    metadata: [self, #file, #function, #line]
                ) {
                    return .failure(exception)
                }

                return .success(translation)
            }

            let decodeResult = await Translation.decode(from: reference)

            switch decodeResult {
            case let .success(translation):
                let input = TranslationInput(translation.input.original.base64Decoded, alternate: translation.input.alternate?.base64Decoded)

                guard !makeIdempotent else {
                    let idempotentTranslation: Translation = .init(
                        input: input,
                        output: input.value().base64Decoded,
                        languagePair: .init(from: translation.languagePair.from, to: translation.languagePair.from)
                    )

                    return validateAndReturn(idempotentTranslation)
                }

                return validateAndReturn(.init(
                    input: input,
                    output: translation.output.base64Decoded,
                    languagePair: translation.languagePair
                ))

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

        guard !makeIdempotent else {
            let getTranslationResult = await getTranslation(firstReference)

            switch getTranslationResult {
            case let .success(translation):
                let input = TranslationInput(translation.input.original.base64Decoded, alternate: translation.input.alternate?.base64Decoded)
                return .success([.init(input: input, output: translation.output.base64Decoded, languagePair: translation.languagePair)])

            case let .failure(exception):
                return .failure(exception)
            }
        }

        var translations = [Translation]()
        for reference in references {
            let getTranslationResult = await getTranslation(reference)

            switch getTranslationResult {
            case let .success(translation):
                let input = TranslationInput(translation.input.original.base64Decoded, alternate: translation.input.alternate?.base64Decoded)
                translations.append(.init(input: input, output: translation.output.base64Decoded, languagePair: translation.languagePair))

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

        guard translations.allSatisfy(\.isWellFormed) else {
            return .failure(.init(
                "Translations fail validation.",
                metadata: [self, #file, #function, #line]
            ))
        }

        return .success(translations)
    }
}
